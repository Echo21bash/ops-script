#!/bin/bash
### 此脚本用于将行式业务表数据同步至列式数据仓库
### 优化点：使用事务块、Join删除、按月分日志、增加统计更新

source /usr/local/greenplum-db/greenplum_path.sh

# 工作目录及日志配置
work_dir=$(cd $(dirname $0); pwd)
current_month=$(date +"%Y-%m")
logfile="${work_dir}/greenplum_sync_${current_month}.log"

# 数据时间间隔可选【1 days】【1 hour】【1 min】
time_interval='1 hour'
start_time=$(date -d "-${time_interval}" +"%Y-%m-%d %H:%M:00")
end_time=$(date +"%Y-%m-%d %H:%M:00")

# 数据库配置
database_name='tyacc_tytest'
index_name='createdAt'
source_schema='AFC_ITP_BUSINESS'
target_schema='AFC_ITP_BIZ_COL'

# 表清单 (确保两个数组一一对应)
tables=(
    'app_pay_bills' 'devices' 'inout_records' 'mobile_pay_bills' 
    'mobile_pay_orders' 'mobile_pay_refundorders' 'orders' 
    'single_ticket_trip_records' 'single_tickets' 'stations' 
    'ticket_matrices' 'user_accounts' 'user_details' 
    'user_pay_accounts' 'user_phone_login'
)

log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] $1" >> "$logfile"
}

log_error() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] $1" >> "$logfile"
}

sync_table() {
    local table_name=$1
    log_message "正在同步表: ${table_name} ..."

    # 核心SQL逻辑：封装在单个事务中
    psql -d "${database_name}" -v ON_ERROR_STOP=1 <<-EOF >> "$logfile" 2>&1
    BEGIN;

    -- 1. 删除目标表中时间区间内可能已存在的重复数据
    DELETE FROM "${target_schema}"."${table_name}" 
    WHERE "${index_name}" > '${start_time}' 
      AND "${index_name}" <= '${end_time}';

    -- 2. 处理历史数据的更新 (使用 JOIN 代替 IN，提升 AO 表关联删除效率)
    DELETE FROM "${target_schema}"."${table_name}" t
    USING "${source_schema}"."${table_name}" s
    WHERE t.id = s.id 
      AND s."${index_name}" < '${start_time}' 
      AND s."updatedAt" >= '${start_time}';

    -- 3. 批量插入：新产生的数据 + 历史被更新的数据
    INSERT INTO "${target_schema}"."${table_name}" 
    SELECT * FROM "${source_schema}"."${table_name}" 
    WHERE ("${index_name}" > '${start_time}' AND "${index_name}" <= '${end_time}')
       OR ("${index_name}" < '${start_time}' AND "updatedAt" >= '${start_time}');

    COMMIT;

    -- 4. 更新统计信息，确保报表查询优化器获得最新分布情况
    ANALYZE "${target_schema}"."${table_name}";
EOF

    if [ $? -eq 0 ]; then
        log_message "表 ${table_name} 同步完成。"
    else
        log_error "表 ${table_name} 同步失败，请检查数据库连接或锁定情况。"
    fi
}

run_main() {
    log_message "========== 行转列同步任务启动 =========="
    log_message "同步区间: [${start_time}] 至 [${end_time}]"

    for table in "${tables[@]}"; do
        sync_table "${table}"
    done

    log_message "========== 所有任务执行完毕 =========="
    echo "------------------------------------------------" >> "$logfile"
}

# 执行主函数
run_main