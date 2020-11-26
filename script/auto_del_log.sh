#!/bin/bash
###################################
#删除日志脚本
###################################
#日志目录
log_dir=('/opt/kafka/logs/' '/opt/tomcat/logs/')
#日志保留天数
day='30'
for now_log_dir in ${log_dir[@]}
do
	find "${now_log_dir}" -mtime +${day} -name "*.log.*" -exec rm -rf {} \;
done
