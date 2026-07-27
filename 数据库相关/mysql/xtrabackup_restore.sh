#!/bin/bash
# 开启严谨模式，避免中途报错继续执行
set -euo pipefail

# ================= 日志配置 =================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"

LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1

# ================= 基础配置 =================
# MySQL 目标数据目录 (还原前必须清空或重命名原目录)
MYSQL_DATA_DIR="/var/lib/mysql"
MYSQL_USER="mysql"
MYSQL_GROUP="mysql"

# 默认备份主根目录 (需要与备份脚本保持一致)
WORK_DIR="/data/backup_data"
FULL_BACKUP_BASE="${WORK_DIR}/full_backup_mysql"
INC_BACKUP_BASE="${WORK_DIR}/incremental_backup_mysql"

# 准备恢复的临时工作目录 (建议放在空间充裕的磁盘)
RESTORE_TEMP_DIR="/data/restore_temp_$(date +%Y%m%d_%H%M%S)"

# ================= 辅助函数 =================

log_info() {
    echo -e "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# 校验恢复环境
check_environment() {
    log_info "1. 检查恢复环境..."

    # 1.1 检查 xtrabackup 和 qpress (解压依赖) 工具
    if ! command -v xtrabackup &>/dev/null; then
        log_error "未找到 xtrabackup 命令，请先安装！"
        exit 1
    fi
    if ! command -v qpress &>/dev/null; then
        log_error "未找到 qpress 命令（解压 --compress 需要），请通过 epel 源安装 qpress！"
        exit 1
    fi

    # 1.2 检查 MySQL 服务是否已停止
    if systemctl is-active --quiet mysqld || systemctl is-active --quiet mysql; then
        log_error "MySQL 服务正在运行！为防止数据损坏，请先停止 MySQL 服务 (systemctl stop mysqld)。"
        exit 1
    fi

    # 1.3 校验数据目录是否存在且为空
    if [ -d "${MYSQL_DATA_DIR}" ] && [ "$(ls -A "${MYSQL_DATA_DIR}")" ]; then
        log_error "目标数据目录 ${MYSQL_DATA_DIR} 不为空！"
        log_error "请先备份并清空该目录（例如：mv ${MYSQL_DATA_DIR} ${MYSQL_DATA_DIR}_bak_$(date +%Y%m%d)）"
        exit 1
    fi
}

# 用户交互式选择恢复路径
select_backup_dir() {
    log_info "2. 确认备份源文件目录..."

    # 如果运行脚本时带了参数 $1，则作为全量目录，否则自动选择最新的全量备份
    if [ -n "${1:-}" ]; then
        TARGET_FULL_DIR="$1"
    else
        log_info "查找最新的全量备份目录..."
        TARGET_FULL_DIR=$(find "${FULL_BACKUP_BASE}" -mindepth 2 -maxdepth 2 -type d -name "mysql-*-all" 2>/dev/null | sort -r | head -n 1)
    fi

    if [ -z "${TARGET_FULL_DIR}" ] || [ ! -d "${TARGET_FULL_DIR}" ]; then
        log_error "未找到有效的全量备份目录！"
        exit 1
    fi

    log_info "选中的全量备份目录: ${TARGET_FULL_DIR}"

    # 自动检索对应的增量备份目录 (找出在该全量备份之后产生的所有增量备份，按时间升序排列)
    # 提取全量备份目录的时间戳字符串 (mysql-YYYYMMDDHHMM-all)
    FULL_TIME_STR=$(basename "${TARGET_FULL_DIR}" | awk -F'-' '{print $2}')
    
    mapfile -t INC_DIRS < <(find "${INC_BACKUP_BASE}" -mindepth 2 -maxdepth 2 -type d -name "mysql-*-incremental" 2>/dev/null | sort | awk -F'mysql-' -v ftime="${FULL_TIME_STR}" '$2 > ftime')

    if [ ${#INC_DIRS[@]} -gt 0 ]; then
        log_info "检测到以下连续的增量备份，将依次进行合并："
        for dir in "${INC_DIRS[@]}"; do
            echo "  --> ${dir}"
        done
    else
        log_info "未检测到关联的增量备份，将仅恢复此全量备份。"
    fi

    read -p "确认使用上述备份进行还原？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "操作被用户取消。"
        exit 0
    fi
}

# 复制备份至临时工作区并解压
prepare_workspace() {
    log_info "3. 拷贝备份文件至工作目录: ${RESTORE_TEMP_DIR}"
    mkdir -p "${RESTORE_TEMP_DIR}/full"
    
    log_info "正在复制全量备份..."
    cp -r "${TARGET_FULL_DIR}/." "${RESTORE_TEMP_DIR}/full/"

    log_info "正在解压全量备份文件..."
    xtrabackup --decompress --target-dir="${RESTORE_TEMP_DIR}/full" --parallel=8

    if [ ${#INC_DIRS[@]} -gt 0 ]; then
        mkdir -p "${RESTORE_TEMP_DIR}/inc"
        local idx=1
        for inc_path in "${INC_DIRS[@]}"; do
            local dest="${RESTORE_TEMP_DIR}/inc/inc_${idx}"
            mkdir -p "${dest}"
            log_info "正在复制并解压增量备份 [${idx}]: ${inc_path}"
            cp -r "${inc_path}/." "${dest}/"
            xtrabackup --decompress --target-dir="${dest}" --parallel=8
            ((idx++))
        done
    fi
}

# 应用日志（Prepare 阶段）
apply_logs() {
    log_info "4. 开始合并与准备数据 (Apply-Log)..."

    # 4.1 准备全量备份 (如果有增量，全量备份必须加上 --apply-log-only)
    if [ ${#INC_DIRS[@]} -gt 0 ]; then
        log_info "Prepare 全量备份 (保留未提交事务，准备合并增量)..."
        xtrabackup --prepare --apply-log-only --target-dir="${RESTORE_TEMP_DIR}/full"
        
        # 4.2 逐个合并增量备份
        local total_inc=${#INC_DIRS[@]}
        local current=1

        for inc_path in "${INC_DIRS[@]}"; do
            local inc_dir="${RESTORE_TEMP_DIR}/inc/inc_${current}"
            if [ ${current} -lt ${total_inc} ]; then
                log_info "合并增量备份 [${current}/${total_inc}] (--apply-log-only)..."
                xtrabackup --prepare --apply-log-only \
                    --target-dir="${RESTORE_TEMP_DIR}/full" \
                    --incremental-dir="${inc_dir}"
            else
                log_info "合并最后一个增量备份 [${current}/${total_inc}]..."
                xtrabackup --prepare \
                    --target-dir="${RESTORE_TEMP_DIR}/full" \
                    --incremental-dir="${inc_dir}"
            fi
            ((current++))
        done
    else
        log_info "仅恢复全量备份，直接进行 Final Prepare..."
        xtrabackup --prepare --target-dir="${RESTORE_TEMP_DIR}/full"
    fi
}

# 还原数据到 MySQL 目录
restore_data() {
    log_info "5. 将数据拷贝至 MySQL 数据目录: ${MYSQL_DATA_DIR}"
    mkdir -p "${MYSQL_DATA_DIR}"
    
    xtrabackup --copy-back --target-dir="${RESTORE_TEMP_DIR}/full"

    log_info "6. 修改目录权限为 ${MYSQL_USER}:${MYSQL_GROUP}..."
    chown -R "${MYSQL_USER}:${MYSQL_GROUP}" "${MYSQL_DATA_DIR}"
}

# 清理临时工作目录
clean_temp() {
    log_info "7. 清理临时解压工作区: ${RESTORE_TEMP_DIR}"
    rm -rf "${RESTORE_TEMP_DIR}"
}

# ================= 主流程 =================
main() {
    echo "====================================================================================="
    log_info "MySQL XtraBackup 恢复程序启动"
    echo "====================================================================================="

    check_environment
    select_backup_dir "${1:-}"
    
    # 捕获异常信号，确保异常退出时提示保留的临时目录
    trap 'log_error "恢复过程中发生错误！请检查日志。临时目录保留在: ${RESTORE_TEMP_DIR}"' ERR

    prepare_workspace
    apply_logs
    restore_data
    clean_temp

    echo "====================================================================================="
    log_info "MySQL 备份还原成功！"
    log_info "请使用以下命令启动 MySQL 服务："
    log_info "  systemctl start mysqld (或 systemctl start mysql)"
    echo "====================================================================================="
}

main "$@"
