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
logfile=${work_dir}/del_file_list.log
#删除文件夹记录文件
del_file_list=${work_dir}/del_file_list.txt
#保留天数
retention_days='30'

delete_file(){


	>${del_file_list}
	#获取满足条件的目录
	for now_file_dir in ${file_dir[@]}
	do
		find ${now_file_dir} -maxdepth 1 \( ! -regex '.*/\..*' \) -mtime +${retention_days}  -type d >> ${del_file_list}
		find ${now_file_dir} -maxdepth 1 \( ! -regex '.*/\..*' \) -mtime +${retention_days}  -type f >> ${del_file_list}
	done
	#清空目录
	for now_del_file in `cat ${work_dir}/del_file_list.txt`
	do
		if [[ ! -z ${now_del_file} ]];then
			if [[ -d ${now_del_file} ]];then
				#清空文件夹
				echo -e "Clearing directory ${now_del_file} \c"
				rsync --delete -rlptD /tmp/empty/ ${now_del_file} && rm -rf ${now_del_file}
				if [[ $? = "0" ]];then
					echo "Successful"
				else
					echo "Failed"
				fi
			fi
			if [[ -f ${now_del_file} ]];then
				#清空文件
				echo -e "Deleting file ${now_del_file} \c"
				rm -rf ${now_del_file}
				if [[ $? = "0" ]];then
					echo "Successful"
				else
					echo "Failed"
				fi
			fi
		fi
	done
}

main(){

	if [[ ! -d /tmp/empty/ ]];then
		mkdir -p /tmp/empty/
	else
		rm -rf /tmp/empty/*
	fi
	start_date=$(date)
	echo "开始时间 ${start_date}" >> ${logfile}
	delete_file >> ${logfile}
	end_date=$(date)
	echo "结束时间 ${end_date}" >> ${logfile}
}
main
