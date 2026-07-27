#!/bin/bash
# 开启严谨模式
set -u

# ================= 日志配置 =================
# 获取脚本自身路径和名称
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

# 创建日志目录 logs
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"

# 日志文件名：脚本名_日期.log
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}_$(date +%Y%m%d).log"

# 将所有输出同时定向到标准输出和日志文件
exec > >(tee -a "${LOG_FILE}") 2>&1

# ================= 基础配置 =================
MYSQL_USER="xtrabackup"
MYSQL_PASSWORD="xtrabackup98765^^FF"
MYSQL_HOST="172.16.2.203"
MYSQL_PORT="9920"

work_dir="/data/backup_data"
backup_retention_days=14 # 备份数据保留 14 天
log_retention_days=30    # 日志文件保留 30 天（一个月）
xtrabackup_timeout="3h"

textfile_collector_dir="/usr/local/node_exporter/textfile_collector"

rsync_bwlimit="30M"
rsync_mod_name="backup"
backup_host="172.16.2.151"
backup_user="rsync"

# ================= 动态变量 =================
string_time=$(date +%Y%m%d%H%M)
file_path_time=$(date +%W) # 周数目录
day_of_week=$(date +%w)   # 0 表示周日

full_work_dir="${work_dir}/full_backup_mysql"
full_file_path="${full_work_dir}/${file_path_time}"

incremental_work_dir="${work_dir}/incremental_backup_mysql"
incremental_file_path="${incremental_work_dir}/${file_path_time}"

# 检查本机是否挂载 VIP
is_primary() {
    ip addr show | grep -qw "${MYSQL_HOST}"
}

# 获取最新的全量备份目录
get_latest_full_dir() {
    find "${full_work_dir}" -mindepth 2 -maxdepth 2 -type d -name "mysql-*-all" 2>/dev/null | sort -r | head -n 1
}

# 清理超过 30 天的日志文件
clean_old_logs() {
    echo "==== 清理超过 ${log_retention_days} 天的旧日志文件 ===="
    find "${LOG_DIR}" -type f -name "${SCRIPT_NAME}_*.log" -mtime +${log_retention_days} -exec rm -f {} + 2>/dev/null
}

# ================= 备份函数 =================

# 1. 全量备份
mysql_full_backup() {
    start_date=$(date)
    mkdir -p "${full_file_path}"

    target_dir="${full_file_path}/mysql-${string_time}-all"

    echo "==== 开始 MySQL 全量备份 ===="
    timeout ${xtrabackup_timeout} xtrabackup \
        --user="${MYSQL_USER}" \
        --password="${MYSQL_PASSWORD}" \
        --host="${MYSQL_HOST}" \
        --port="${MYSQL_PORT}" \
        --compress \
        --compress-threads=16 \
        --ftwrl-wait-timeout=120 \
        --backup \
        --no-server-version-check \
        --target-dir="${target_dir}"
    
    xtrabackup_exit_code=$?
    end_date=$(date)

    echo "MySQL 全量备份执行完成!"
    echo "开始时间: ${start_date}"
    echo "结束时间: ${end_date}"
    echo "备份目录: ${target_dir}"
    echo "任务执行状态码: ${xtrabackup_exit_code} (0:成功; 非0:失败)"
    echo "-------------------------------------------------------------------------------------"
}

# 2. 增量备份
mysql_incremental_backup() {
    start_date=$(date)
    latest_full_dir=$(get_latest_full_dir)

    # 如果找不到任何全量备份，自动切换为全量备份
    if [[ -z "${latest_full_dir}" ]]; then
        echo "[警告] 未找到基准全量备份目录，自动切换为全量备份模式！"
        mysql_full_backup
        return
    fi

    mkdir -p "${incremental_file_path}"
    target_dir="${incremental_file_path}/mysql-${string_time}-incremental"

    echo "==== 开始 MySQL 增量备份 ===="
    timeout ${xtrabackup_timeout} xtrabackup \
        --user="${MYSQL_USER}" \
        --password="${MYSQL_PASSWORD}" \
        --host="${MYSQL_HOST}" \
        --port="${MYSQL_PORT}" \
        --compress \
        --compress-threads=16 \
        --ftwrl-wait-timeout=120 \
        --backup \
        --no-server-version-check \
        --incremental-basedir="${latest_full_dir}" \
        --target-dir="${target_dir}"
    
    xtrabackup_exit_code=$?
    end_date=$(date)

    echo "MySQL 增量备份执行完成!"
    echo "开始时间: ${start_date}"
    echo "结束时间: ${end_date}"
    echo "依据全量备份目录: ${latest_full_dir}"
    echo "备份目录: ${target_dir}"
    echo "任务执行状态码: ${xtrabackup_exit_code} (0:成功; 非0:失败)"
    echo "-------------------------------------------------------------------------------------"
}

# 3. 清理备份文件
clean_backup() {
    start_date=$(date)

    echo "==== 开始清理旧备份目录 ===="
    find "${full_work_dir}" -type d -mtime +${backup_retention_days} -exec rm -rf {} + 2>/dev/null
    find "${incremental_work_dir}" -type d -mtime +${backup_retention_days} -exec rm -rf {} + 2>/dev/null

    clean_exit_code=$?
    end_date=$(date)

    echo "清理备份文件执行完成！"
    echo "开始时间: ${start_date}"
    echo "结束时间: ${end_date}"
    echo "任务执行状态码: ${clean_exit_code} (0:成功; 非0:失败)"
    echo "-------------------------------------------------------------------------------------"
}

# 4. 生成 Prometheus 监控指标
make_monitoring_data() {
    if [[ -n "${textfile_collector_dir}" ]]; then
        mkdir -p "${textfile_collector_dir}"
        cat <<EOF > "${textfile_collector_dir}/promethues.mysqlbackup.prom.tmp"
# HELP mysql_backup_status mysql backup status
# TYPE mysql_backup_status gauge
mysql_backup_status{mysqlhost="${MYSQL_HOST}"} ${xtrabackup_exit_code}
EOF
        # 原子覆盖，防止并发读取空文件
        mv "${textfile_collector_dir}/promethues.mysqlbackup.prom.tmp" "${textfile_collector_dir}/promethues.mysqlbackup.prom"
    fi
}

# 5. 远程传输备份文件
rsync_backup_file() {
    start_date=$(date)

    echo "==== 开始远程传输备份 ===="
    if [ "${day_of_week}" == "0" ]; then
        local_path="${full_file_path}/mysql-${string_time}-all"
        remote_target="${backup_user}@${backup_host}::${rsync_mod_name}/${MYSQL_HOST}/mysql-${string_time}-all"
    else
        local_path="${incremental_file_path}/mysql-${string_time}-incremental"
        remote_target="${backup_user}@${backup_host}::${rsync_mod_name}/${MYSQL_HOST}/mysql-${string_time}-incremental"
    fi

    rsync -avz --bwlimit=${rsync_bwlimit} --password-file=/etc/rsync.passwd \
        "${local_path}" "${remote_target}"
    
    rsync_exit_code=$?
    end_date=$(date)

    echo "传输备份执行完成！"
    echo "开始时间: ${start_date}"
    echo "结束时间: ${end_date}"
    echo "任务执行状态码: ${rsync_exit_code} (0:成功; 非0:失败)"
    echo "-------------------------------------------------------------------------------------"
}

# ================= 主流程 =================
main() {
    echo "====================================================================================="
    echo "开始执行备份脚本: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # 每次运行顺便清理日志目录中超过 30 天的日志
    clean_old_logs

    if is_primary; then
        latest_full=$(get_latest_full_dir)

        if [[ "${day_of_week}" == "0" || -z "${latest_full}" ]]; then
            mysql_full_backup
            if [[ ${xtrabackup_exit_code} -eq 0 ]]; then
                clean_backup
            fi
        else
            mysql_incremental_backup
        fi

        make_monitoring_data

        if [[ ${xtrabackup_exit_code} -eq 0 ]]; then
            rsync_backup_file
        fi
    else
        echo "本机不是 PRIMARY (${MYSQL_HOST})，跳过备份！"
        echo "日期: $(date)"
        echo "-------------------------------------------------------------------------------------"
    fi
}

main

