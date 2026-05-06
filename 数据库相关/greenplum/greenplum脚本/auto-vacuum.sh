#!/bin/bash
#auto exec vacuum full
#do not echo command, just get a list of db
source /usr/local/greenplum-db/greenplum_path.sh
week=`date +%w`
work_dir='/home/gpadmin/itp_tool'
log_file="${work_dir}/vacuum.log"
dblist=`psql -d postgres -c "copy (select datname from pg_stat_database) to stdout"`
dblist=($dblist)
dblist=('lcdb' 'tyacc_tytest')
#申明关联数组
declare -A schema_name
schema_name=([tyacc_tytest]='AFC_ITP_BUSINESS AFC_ITP_SDK AFC_ITP_BIZ_COL AFC_ITP_FACE' [lcdb]='afc_txn')

kill_transaction(){
	###杀掉超过一天的事务
	psql  <<-EOF
	\timing
	SELECT pg_terminate_backend(pid)
	FROM 
      (SELECT pid
	FROM pg_stat_activity
	WHERE (now() - xact_start > interval '3590 min' OR now() - query_start > interval '3590 min') AND query !~ '^COPY' AND state LIKE '%transaction%'
	ORDER BY  coalesce(xact_start, query_start)) a;
	EOF
}
get_all_tables(){
	###获取所有表
	tables_file="${work_dir}/${db}_table_list.txt"
	system_tables_file="${work_dir}/${db}_system_table_list.txt"
	>${tables_file}
	>${system_tables_file}
	#skip system databases
	if [[ $db == template0 ]] || [[ $db == template1 ]] || [[ $db == postgres ]] || [[ $db == gpdb ]] ; then
		continue
	fi
	
	#query out only the normal user tables, excluding partitions of parent tables
	schema_list=(${schema_name[$db]})
	for schema in ${schema_list[@]}
	do
		psql -d $db -c "copy (select '\"'||tables.schemaname||'\".' || '\"'||tables.tablename||'\"' from (select nspname as schemaname, relname as tablename from pg_catalog.pg_class, pg_catalog.pg_namespace, pg_catalog.pg_roles where pg_class.relnamespace = pg_namespace.oid and pg_namespace.nspowner = pg_roles.oid and pg_class.relkind='r' and (pg_namespace.nspname = '${schema}' or pg_roles.rolsuper = 'false' ) ) as tables(schemaname, tablename) left join pg_catalog.pg_partitions on pg_partitions.partitionschemaname=tables.schemaname and pg_partitions.partitiontablename=tables.tablename where pg_partitions.partitiontablename is null) to stdout;" >>${tables_file}
	done
	psql -d $db -c "copy (SELECT 'pg_catalog.' || relname  from pg_class a, pg_namespace b where a.relnamespace=b.oid and b.nspname='pg_catalog' and a.relkind='r') to stdout;" >>${system_tables_file}

}

run_analyze(){
    ###更新统计信息
    echo "======================开始更新业务表统计信息======================"
	while read line; do
		#some table name may contain the $ sign, so escape it
		line=`echo $line |sed 's/\\\$/\\\\\\\$/g'`
		#vacuum full this table, which will lock the table
		psql -d $db -L ${log_file} -e -a -c "ANALYZE $line;" &
	done <${tables_file}
	
	while true; do
		sleep 10
		proc=`psql -e -a -c "select * from pg_stat_activity;" | grep -oiE 'VACUUM|REINDEX|ANALYZE'`
		if [[ -z $proc ]];then
			echo "======================结束更新业务表统计信息======================"
			return
		fi
	done
	
    ###更新统计信息
    echo "======================开始更新系统表统计信息======================"
	while read line; do
		#some table name may contain the $ sign, so escape it
		line=`echo $line |sed 's/\\\$/\\\\\\\$/g'`
		#vacuum full this table, which will lock the table
		psql -d $db -L ${log_file} -e -a -c "ANALYZE $line;" &
	done <${system_tables_file}
	
	while true; do
		sleep 10
		proc=`psql -e -a -c "select * from pg_stat_activity;" | grep -oiE 'VACUUM|REINDEX|ANALYZE'`
		if [[ -z $proc ]];then
			echo "======================结束更新系统表统计信息======================"
			return
		fi
	done
}

get_vacuum_table(){
	###膨胀表详情
	vacuum_tables_detail="${work_dir}/${db}_vacuum_tables_detail.txt"
	vacuum_tables="${work_dir}/${db}_vacuum_tables.txt"
	###将过期数据大于10000条的表筛选出来
	psql -d $db -c "copy (WITH h AS (
    SELECT '\"' || schemaname || '\".\"' || relname || '\"' AS table_name,
           round(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS ratio
    FROM pg_stat_all_tables 
    WHERE n_dead_tup >= 10000
      AND n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0) > 20
),
a AS (
    SELECT '\"' || t2.nspname || '\".\"' || t1.relname || '\"' AS table_name,
           ROUND(SUM(hidden_tupcount) * 100.0 / NULLIF(SUM(total_tupcount), 0), 2) AS ratio
    FROM pg_class t1
    JOIN pg_namespace t2 ON t1.relnamespace = t2.oid
    CROSS JOIN LATERAL gp_toolkit.__gp_aovisimap_compaction_info(t1.oid) AS info
    WHERE t1.relstorage IN ('a', 'c')
      AND hidden_tupcount > 10000
    GROUP BY t2.nspname, t1.relname, t1.oid
    HAVING SUM(hidden_tupcount) * 100.0 / NULLIF(SUM(total_tupcount), 0) > 20
)
SELECT table_name
FROM (
    SELECT table_name, ratio FROM h 
    UNION ALL 
    SELECT table_name, ratio FROM a
) t
ORDER BY ratio DESC
LIMIT 30) to stdout;" >${vacuum_tables_detail}
	###提取表名并加双引号
	#awk '{print$1}' ${vacuum_tables_detail} |  awk -F '.' '{print "\"" $1 "\"" "." "\""$2"\""}' >${vacuum_tables}
}

run_table_vacuum(){
    ###表膨胀处理
    echo "======================开始表膨胀处理======================"
	while read line; do
		#some table name may contain the $ sign, so escape it
		line=`echo $line |sed 's/\\\$/\\\\\\\$/g'`
		#vacuum full this table, which will lock the table
		sleep 1
		psql -d $db -L ${log_file} -e -a -c "$exec $line;" && \
		psql -d $db -L ${log_file} -e -a -c "set lock_timeout = '1s';REINDEX TABLE $line;" && \
		psql -d $db -L ${log_file} -e -a -c "ANALYZE $line;" &
	done <${vacuum_tables_detail}
	
	while true; do
		sleep 10
		proc=`psql -e -a -c "select * from pg_stat_activity;" | grep -oiE 'VACUUM|REINDEX|ANALYZE'`
		if [[ -z $proc ]];then
			echo "======================结束表膨胀处理======================"
			return
		fi
	done
}

run_ctrl(){

	kill_transaction >>${log_file}
	for db in ${dblist[@]} ; do
		echo "======================开始数据库${db}表膨胀处理======================"
		get_all_tables >>${log_file}
		start_time=`date +'%Y-%m-%d %H:%M:%S'`
		start_seconds=$(date --date="$start_time" +%s)
		run_analyze >>${log_file}
		get_vacuum_table >>${log_file}
		run_table_vacuum >>${log_file}
		end_time=`date +'%Y-%m-%d %H:%M:%S'`
		end_seconds=$(date --date="$end_time" +%s)
		echo "======================结束数据库${db}表膨胀处理======================"
		echo "本次VACUUM ${db} 运行时间："$((end_seconds-start_seconds))"s" >>${log_file}
	done
	
}

main(){
	
	if [[ ${week} = '5' ]];then
		exec='VACUUM FULL VERBOSE'
	else
		exec='VACUUM FREEZE VERBOSE'
	fi
	start_run_time=`date +'%Y-%m-%d %H:%M:%S'`
	echo "开始处理表膨胀${start_run_time}" >>${log_file}
	run_ctrl >>${log_file}
	end_run_time=`date +'%Y-%m-%d %H:%M:%S'`
	echo "完成处理表膨胀${end_run_time}" >>${log_file}
	start_seconds=$(date --date="$start_run_time" +%s);
	end_seconds=$(date --date="$end_run_time" +%s);
	echo "本次总运行时间："$((end_seconds-start_seconds))"s" >>${log_file}

}

main	
