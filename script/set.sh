#!/bin/bash

. ./base.sh

config(){
	input_option "请输入监控目录" "/data/youku" "file_dir"
	file_dir=${input_value}
	input_option "文件监控周期秒" "120" "time_out"
	input_option "请输入日志目录" "/opt/logs" "logs_dir"
	logs_dir=${input_value}
	output_option "请输入需要删除的比例" "0.05 0.1 0.2 0.3 0.4 0.5" "ratio"
	ratio=${output_value}
	input_option "请输入需要删除访问次数低于多少" "10" "access"
	cat >./config<<-EOF
	#监控目录设置可以多个
	file_dir=${file_dir}
	#日志目录
	logs_dir=${logs_dir}
	#文件监控周期秒
	time_out=${time_out}
	#删除的比例
	ratio=${ratio}
	#删除次数临界值
	access=${access}
	EOF
}
config