#!/bin/bash
# 该脚本为监听文件修改时触发sync同步
# 每个模式名称对应关联一个需要同步的目录，要求模式名唯一
declare -A rsync_module_name=([clickhouse]='/data/clickhouse' [k8score]='/data/k8score' [k8smonitor]='/data/k8smonitor')
# 监听排除目录
declare -A exclude_file_rule=([clickhouse]='tmp_insert|tmp_merge|delete_tmp' [k8score]='' [k8smonitor]='')
# rsync脚本路径
sersync_path=/usr/local/sersync/sersync.sh
# 临时目录
inotify_tmp_dir=/tmp/inotify-tmp

inotify_fun(){
	cd $sync_dir
	if [[ -n ${exclude_file} ]];then
		inotifywait --exclude "${exclude_file}" -mrq --format "%Xe %w%f" -e create,delete,attrib,close_write,move ./ | while read event file
		do
			echo "${sync_dir} ${module_name} ${event} ${file}" >> ${inotify_tmp_dir}/inotify-file.log
		done || echo "[error] Failed to monitor $sync_dir"
	else
		inotifywait -mrq --format "%Xe %w%f" -e create,delete,attrib,close_write,move ./ | while read event file
		do
			echo "${sync_dir} ${module_name} ${event} ${file}" >> ${inotify_tmp_dir}/inotify-file.log
		done || echo "[error] Failed to monitor $sync_dir"
	fi
}

rsync_fun(){
	while true
	do
		sleep 20
		if [[ -s ${inotify_tmp_dir}/inotify-file.log ]];then
			\mv ${inotify_tmp_dir}/inotify-file.log ${inotify_tmp_dir}/inotify-tmp.log
			##对重复文件的事件去重并保留最新的事件类型
			awk '{a[$4]=$0}END{for(i in a){print a[i]}}' ${inotify_tmp_dir}/inotify-tmp.log | while read sync_dir module_name event file
			do	
				sleep 0.001
				file=$(echo $file | sed -e 's^ ^\\ ^'g)
				lockfile=$(echo -n "${file}" | md5sum | awk '{print $1}')
				##对rsync操作加锁防止多个周期一个文件重复同步
				flock -n -x $inotify_tmp_dir/$lockfile -c "$sersync_path $sync_dir $module_name $event $file;rm -rf $inotify_tmp_dir/$lockfile" &
			done
		fi
	done
}

run_ctl(){
	if [[ ! -d $inotify_tmp_dir ]];then
		mkdir -p $inotify_tmp_dir
	fi
	for i in ${!rsync_module_name[@]}
	do
		#rsyncd模块名
		module_name="${i}"
		#同步目录
		sync_dir="${rsync_module_name[$i]}"
		#监听排除规则
		exclude_file="${exclude_file_rule[$i]}"
		echo "[info] Start monitor $sync_dir"
		inotify_fun &
	done
	rsync_fun &
}


run_ctl
