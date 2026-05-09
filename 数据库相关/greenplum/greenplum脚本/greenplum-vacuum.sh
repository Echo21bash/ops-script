#!/bin/bash
# Greenplum 自动表维护维护脚本
# 优化点：日志按月滚动、限制并发、增加锁超时保护

source /usr/local/greenplum-db/greenplum_path.sh

# --- 配置区 ---
work_dir=$(cd $(dirname $0); pwd)
current_month=$(date +"%Y-%m")
log_file="${work_dir}/greenplum_vacuum_$(date +%Y%m).log"

# 星期几
week=$(date +%w)
# 限制并发进程数，建议设置为 Segment 节点的 1/4 或更低，此处设为 3
parallel_tasks=3

# 数据库列表及对应的 Schema
dblist=('lcdb' 'tyacc_tytest')
declare -A schema_name
schema_name=([tyacc_tytest]='AFC_ITP_BUSINESS AFC_ITP_SDK AFC_ITP_BIZ_COL AFC_ITP_FACE' [lcdb]='afc_txn')

# --- 辅助函数 ---
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "${log_file}"
}

kill_transaction(){
    log_info "正在清理长事务 (超过 3590 分钟)..."
    psql -d postgres -c "
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE (now() - xact_start > interval '3590 min') 
      AND query !~ '^COPY' 
      AND state LIKE '%transaction%'
      AND pid <> pg_backend_pid();" >> "${log_file}" 2>&1
}

# --- 核心逻辑 ---

get_all_tables(){
    local db=$1
    tables_file="${work_dir}/${db}_table_list.txt"
    system_tables_file="${work_dir}/${db}_system_table_list.txt"
    > "${tables_file}"
    > "${system_tables_file}"

    # 获取业务表
    schema_list=(${schema_name[$db]})
    for schema in ${schema_list[@]}; do
        psql -d "${db}" -t -c "
        SELECT '\"' || n.nspname || '\".\"' || c.relname || '\"'
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        LEFT JOIN pg_partitions p ON p.schemaname = n.nspname AND p.partitiontablename = c.relname
        WHERE n.nspname = '${schema}' 
          AND c.relkind = 'r' 
          AND p.partitiontablename IS NULL;" >> "${tables_file}"
    done

    # 获取系统表
    psql -d "${db}" -t -c "
    SELECT 'pg_catalog.\"' || relname || '\"' 
    FROM pg_class a, pg_namespace b 
    WHERE a.relnamespace=b.oid AND b.nspname='pg_catalog' AND a.relkind='r';" >> "${system_tables_file}"
}

run_analyze(){
    local db=$1
    local file=$2
    local type_name=$3
    log_info "开始更新 ${type_name} 统计信息 (并发: ${parallel_tasks})..."
    
    # 修复：使用 -d '\n' 强制 xargs 原封不动传递包含双引号的行
    cat "${file}" | grep '[^[:space:]]' | xargs -d '\n' -I {} -P ${parallel_tasks} psql -d "${db}" -e -c 'SET lock_timeout = "60s"; ANALYZE {};' >> "${log_file}" 2>&1
    
    log_info "结束更新 ${type_name} 统计信息。"
}

get_vacuum_table(){
    local db=$1
    vacuum_tables_detail="${work_dir}/${db}_vacuum_tables_detail.txt"
    log_info "正在分析 ${db} 膨胀表详情..."
    # 堆表膨胀统计
	psql -d $db -c "copy (SELECT
	'HEAP' :: TEXT AS TYPE,
	TABLE_NAME,
	pg_size_pretty ( total_size ) AS SIZE,
	dirty,
	live,
	ratio 
	FROM
	(
	SELECT
		'\"' || schemaname || '\".\"' || relname || '\"' AS TABLE_NAME,
		SUM ( relsize ) AS total_size,
		SUM ( n_dead_tup ) :: BIGINT AS dirty,
		SUM ( n_live_tup ) :: BIGINT AS live,
		ROUND( SUM ( n_dead_tup ) * 100.0 / NULLIF ( SUM ( n_live_tup + n_dead_tup ), 0 ), 2 ) AS ratio 
	FROM
		(-- 从所有 Segment 节点抓取实时统计信息
		SELECT
			s.schemaname,
			s.relname,
			pg_relation_size ( s.relid ) AS relsize,
			pg_stat_get_dead_tuples ( s.relid ) AS n_dead_tup,
			pg_stat_get_live_tuples ( s.relid ) AS n_live_tup 
		FROM
			gp_dist_random ( 'pg_stat_all_tables' ) s
			JOIN pg_class C ON s.relid = C.oid 
		WHERE
			C.relkind = 'r' 
			AND C.relstorage = 'h' -- 仅限堆表
			
		) all_segments 
	GROUP BY
		schemaname,
		relname 
	) T 
	WHERE
	dirty >= 10000 
	AND ratio > 20 
	ORDER BY
	ratio DESC 
	LIMIT 20) to stdout;" >${vacuum_tables_detail}
	
	# AO表膨胀统计
	psql -d $db -c "copy (SELECT 
    'AO'::text AS type,
    table_name,
    pg_size_pretty(total_size) AS size,
    dirty,
    live,
    ratio
	FROM (
    SELECT 
        '\"' || t2.nspname || '\".\"' || t1.relname || '\"' AS table_name,
        pg_relation_size(t1.oid) AS total_size,
        SUM(hidden_tupcount)::bigint AS dirty,
        SUM(total_tupcount)::bigint AS live,
        ROUND(SUM(hidden_tupcount) * 100.0 / NULLIF(SUM(total_tupcount), 0), 2) AS ratio
    FROM pg_class t1
    JOIN pg_namespace t2 ON t1.relnamespace = t2.oid
    CROSS JOIN LATERAL gp_toolkit.__gp_aovisimap_compaction_info(t1.oid) AS info
    WHERE t1.relstorage IN ('a', 'c')
    GROUP BY t2.nspname, t1.relname, t1.oid
	) t
	WHERE dirty >= 10000
	AND ratio > 20
	ORDER BY ratio DESC
	LIMIT 20) to stdout;" >>${vacuum_tables_detail}
}

run_table_vacuum(){
    local db=$1
    local exec_cmd=$2
    log_info "开始执行表膨胀维护 (模式: ${exec_cmd})..."

    # 1：awk 提取第二列
    # 2：xargs -d '\n' 保护双引号不被剥离
    # 3：bash -c 内部使用单引号包裹 SQL 字符串
    awk '{print $2}' "${work_dir}/${db}_vacuum_tables_detail.txt" | xargs -d '\n' -I {} -P ${parallel_tasks} bash -c "
        export PGOPTIONS=\"-c lock_timeout=3000\"
        psql -d ${db} -e -c '${exec_cmd} {};' && \
        psql -d ${db} -e -c 'REINDEX TABLE {};' && \
        psql -d ${db} -e -c 'ANALYZE {};'
    " >> "${log_file}" 2>&1
    
    log_info "完成表膨胀维护。"
}

# --- 主控制流 ---

main(){
    # 根据周五执行 FULL，其余时间执行 FREEZE
    if [[ "${week}" == "5" ]]; then
        exec_mode='VACUUM FULL'
    else
        exec_mode='VACUUM FREEZE'
    fi

    log_info "############ 脚本启动 ############"
    kill_transaction

    for db in "${dblist[@]}"; do
        log_info "=== 数据库 ${db} 处理开始 ==="
        start_sec=$(date +%s)

        get_all_tables "${db}"
        
        # 1. 先做一次全局业务表和系统表的统计信息更新
        run_analyze "${db}" "${work_dir}/${db}_table_list.txt" "业务表"
        run_analyze "${db}" "${work_dir}/${db}_system_table_list.txt" "系统表"

        # 2. 识别并清理膨胀严重的表
        get_vacuum_table "${db}"
        run_table_vacuum "${db}" "${exec_mode}"

        end_sec=$(date +%s)
        log_info "=== 数据库 ${db} 处理完成，耗时: $((end_sec - start_sec))s ==="
    done

    log_info "############ 脚本结束 ############"
}

# 执行主函数
main
