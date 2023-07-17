#!/bin/bash
######################################
#删除文件脚本使用rsync工具进行删除，适合大
#批量文件删除任务，通过文件修改时间进行筛选。
######################################
#工作目录
work_dir=`cd $(dirname $0);pwd`
#文件目录
file_dir=('/data/itp-face-file/error-face' '/data/itp-face-file/fail-trip')
#日志
logfile=${work_dir}/del_dir.log
#删除文件夹记录文件
del_dir_list=${work_dir}/del_dir_list.txt
#保留天数
day='30'

delete_file(){

	if [[ ! -d /tmp/empty/ ]];then
		mkdir -p /tmp/empty/
	else
		rm -rf /tmp/empty/*
	fi
	>${del_dir_list}
	#获取满足条件的目录
	for now_file_dir in ${file_dir[@]}
	do
		find ${now_file_dir} -maxdepth 1 \( ! -regex '.*/\..*' \) -mtime +${day}  -type d >> ${del_dir_list}
	done
	#清空目录
	for now_del_dir in `cat ${work_dir}/del_dir_list.txt`
	do
		if [[ ! -z ${now_del_dir} ]];then
			#清空文件
			echo -e "Clearing directory ${now_del_dir} \c"
			rsync --delete -rlptD /tmp/empty/ ${now_del_dir} && rm -rf ${now_del_dir}
			if [[ $? = "0" ]];then
				echo "Successful"
			else
				echo "Failed"
			fi
			
		fi
	done
}

delete_file >>${logfile}
