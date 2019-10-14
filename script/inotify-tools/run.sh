#!/bin/bash

. ./base.sh
. ./config
#执行时间
operat_time=`date "+%Y-%m-%d-%H-%M"`
#被监控文件名称
file_list="${logs_dir}/file_list_${operat_time}.txt"
#文件读取报表
read_report="${logs_dir}/read_report_${operat_time}.txt" 
#将要删除的文件列表
delete_file="${logs_dir}/delete_file_${operat_time}.txt" 

creat_all_file_name(){
	> ${file_list}
	for i in ${file_dir[@]};
	do
		if [ -d $i ];then
			find ${i} -maxdepth 1 -name "*${file_type}" >> ${file_list}
		fi
	done
}

listen_file(){

	inotifywatch -v -t ${time_out} -e access  --fromfile ${file_list} | awk '{print $2"\t"$3}' > /tmp/report.txt
}

add_report(){
	report=$(cat /tmp/report.txt | wc -l)
	if [[ -n ${report} ]];then
		while :
		do
			awk 'NR==FNR{a[$2]=$0;print}NR>FNR{if($1 in a);else print 0"\t"$0}' /tmp/report.txt ${file_list} >${read_report}
			if [ $? = 0 ];then
				break
			fi
		done
	fi
}

delete_file(){
	total_num=`awk 'END{print NR}' $read_report`
	save_num=`echo ${total_num}-${total_num}*${ratio}|bc`
	#生成删除文件列表
	awk 'NR>'${save_num}'{print $2}' ${read_report} >${delete_file}
	awk '{if ($1<'${access}')print $2}' ${read_report} >>${delete_file}
	#删除文件
	awk '{print}' ${delete_file} | xargs -n 1 rm -rf
}

mkdir -p ${logs_dir}
creat_all_file_name
listen_file
add_report
delete_file
