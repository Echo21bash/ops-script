#!/bin/bash
set -o pipefail
usage()
{
	cat <<-EOF
	Usage:${program} [OPTION]...
	-f   指定配置文件
	EOF
}

run_script(){

	if [[ ${exec_command_enable} = '1' ]];then
		echo "[INFO] Running the script ${work_dir}/scripts/${exec_shell_file}"
		if [[ $(${work_dir}/scripts/${exec_shell_file}) ]];then
			echo "[INFO] The script ${work_dir}/scripts/${exec_shell_file} execution successful"
		else
			echo "[WARN] The script ${work_dir}/scripts/${exec_shell_file} execution error"
		fi
	fi

}

full_rsync_first(){

	cd ${sync_dir}
	rsync_command_path="${work_dir}/bin/prsync.sh"
	other_extra_args="--parallel=${parallel_rsync_num}"
	run_script
	for ipaddr in ${sync_dir_module_ip[${sync_dir}]}
	do
		rsync_current_date=$(date +%Y-%m-%d)
		rsync_start_time=$(date "+%Y-%m-%d %H:%M:%S")
		rsyncd_ip=$(echo ${ipaddr} | awk -F ':' '{print$1}')
		rsyncd_port=$(echo ${ipaddr} | awk -F ':' '{print$2}')
		rsyncd_port=${rsyncd_port:-873}
		lockfile=$(echo -n "${sync_dir}${rsyncd_ip}" | md5sum | awk '{print $1}')
		###声明变量用于子进程引用
		export rsyncd_ipaddr=${rsyncd_ip}
		export remote_sync_dir=${remote_sync_dir}
		echo "[INFO] Syncing ${sync_dir} in full to ${ipaddr}..."
		SECONDS=0
		flock -n -x -E 111 ${logs_dir}/${lockfile} -c "
		timeout ${full_rsync_timeout}h \
		${rsync_command_path} ${other_extra_args} -rlptDR --delete --port=${rsyncd_port} ${extra_rsync_args} \
		--backup --backup-dir=/history-backup/${remote_sync_dir}/${rsync_current_date} \
		--bwlimit=${rsync_bwlimit} --password-file=${rsync_passwd_file} ./ \
		${rsync_user}@${rsyncd_ip}::${module_name}/${remote_sync_dir}/ && \
		rm -rf ${logs_dir}/${lockfile}" > ${logs_dir}/${remote_sync_dir}.log
		full_rsync_exit_code=$?
		rsync_duration_time=${SECONDS}
		if [[ ${full_rsync_exit_code} = '0' || ${full_rsync_exit_code} = '24' ]];then
			echo "[INFO] Full sync ${sync_dir} complete to ${ipaddr} DONE (${rsync_duration_time}s)"
		elif [[ ${full_rsync_exit_code} = '123' ]];then
			echo "[INFO] Full sync ${sync_dir} complete to ${ipaddr},but there are warnings,please check the logs DONE (${rsync_duration_time}s)"
		elif [[ ${full_rsync_exit_code} = '111' ]];then
			echo "[INFO] Has other processes syncing in ${sync_dir} to ${ipaddr}"
		elif [[ ${full_rsync_exit_code} = '124' ]];then
			echo "[INFO] Timeout exit syncing in ${sync_dir} to ${ipaddr}"
		else
			echo "[ERROR] Error in full sync ${sync_dir} to ${ipaddr}"
		fi
		make_monitoring_data
	done

}

full_rsync_fun(){

	cd ${sync_dir}
	rsync_command_path="${work_dir}/bin/prsync.sh"
	other_extra_args="--parallel=${parallel_rsync_num}"

	old_changes_tatus=$(stat -c %z ${work_dir}/logs/runcron 2>/dev/null)
	while true
	do
		sleep 30
		new_changes_tatus=$(stat -c %z ${work_dir}/logs/runcron 2>/dev/null)

		if [[ ${old_changes_tatus} != ${new_changes_tatus} ]];then
			old_changes_tatus=${new_changes_tatus}
			del_end_rsync_date=$(date -d "-${keep_history_backup_days} day" +%Y-%m-%d)
			run_script
			for ipaddr in ${sync_dir_module_ip[${sync_dir}]}
			do
				rsync_current_date=$(date +%Y-%m-%d)
				rsync_start_time=$(date "+%s")
				rsyncd_ip=$(echo ${ipaddr} | awk -F ':' '{print$1}')
				rsyncd_port=$(echo ${ipaddr} | awk -F ':' '{print$2}')
				rsyncd_port=${rsyncd_port:-873}
				lockfile=$(echo -n "${sync_dir}${rsyncd_ip}" | md5sum | awk '{print $1}')
				###声明变量用于子进程引用
				export rsyncd_ipaddr=${rsyncd_ip}
				export remote_sync_dir=${remote_sync_dir}
				echo "[INFO] Syncing ${sync_dir} in full to ${ipaddr}..."
				SECONDS=0
				flock -n -x -E 111 ${logs_dir}/${lockfile} -c "
				timeout ${full_rsync_timeout}h \
				${rsync_command_path} ${other_extra_args} -rlptDR --delete --port=${rsyncd_port} ${extra_rsync_args} \
				--backup --backup-dir=/history-backup/${remote_sync_dir}/${rsync_current_date} \
				--bwlimit=${rsync_bwlimit} --password-file=${rsync_passwd_file} ./ \
				${rsync_user}@${rsyncd_ip}::${module_name}/${remote_sync_dir}/ && \
				rm -rf ${logs_dir}/${lockfile}" > ${logs_dir}/${remote_sync_dir}.log
				full_rsync_exit_code=$?
				rsync_duration_time=${SECONDS}
				if [[ ${full_rsync_exit_code} = '0' || ${full_rsync_exit_code} = '24' ]];then
					echo "[INFO] Full sync ${sync_dir} complete to ${ipaddr} DONE (${rsync_duration_time}s)"
					###删除历史备份数据
					delete_history_backup
				elif [[ ${full_rsync_exit_code} = '123' ]];then
					echo "[INFO] Full sync ${sync_dir} complete to ${ipaddr},but there are warnings,please check the logs DONE (${rsync_duration_time}s)"
					###删除历史备份数据
					delete_history_backup
				elif [[ ${full_rsync_exit_code} = '111' ]];then
					echo "[INFO] Has other processes syncing in ${sync_dir} to ${ipaddr}"
					break
				elif [[ ${full_rsync_exit_code} = '124' ]];then
					echo "[INFO] Timeout exit syncing in ${sync_dir} to ${ipaddr}"
					break
				else
					echo "[ERROR] Error in full sync ${sync_dir} to ${ipaddr}"
					break
				fi
				make_monitoring_data
			done
		fi
	done

}

delete_history_backup(){
	SECONDS=0
	echo "[INFO] Start delete history backup /history-backup/${remote_sync_dir}/${del_end_rsync_date} in ${ipaddr}"
	${work_dir}/bin/sersync.sh  -m ${module_name} -u ${rsync_user} \
	--rsyncd-ip ${rsyncd_ip} --rsyncd-port ${rsyncd_port} --passwd-file ${rsync_passwd_file} \
	--rsync-root-dir ${logs_dir}/empty --rsync-remote-dir /history-backup/${remote_sync_dir} \
	-f ${del_end_rsync_date} -e DELETEXISDIR --rsync-timeout ${full_rsync_timeout}h \
	--rsync-bwlimit ${rsync_bwlimit} --rsync-extra-args "${extra_rsync_args}" \
	--rsync-command-path ${rsync_command_path} --other-extra-args ${other_extra_args}
	delete_history_exit_code=$?
	if [[ ${delete_history_exit_code} = '0' ]];then
		echo "[INFO] Delete history backup complete /history-backup/${remote_sync_dir}/${del_end_rsync_date} in ${ipaddr} DONE (${SECONDS}s)"
	elif [[ ${delete_history_exit_code} = '124' ]];then
		echo "[INFO] Timeout delete history backup /history-backup/${remote_sync_dir}/${del_end_rsync_date} in ${ipaddr}"
	else
		echo "[ERROR] Some errors occurred while deleting historical backups /history-backup/${remote_sync_dir}/${del_end_rsync_date} in ${ipaddr}"
	fi
}

make_monitoring_data(){
	rsync_files_num=$(grep -oE '[0-9]+ \([0-9]+ MB\)' ${logs_dir}/${remote_sync_dir}.log | grep -oE '^[0-9]+')
	rsync_files_size=$(grep -oE '[0-9]+ \([0-9]+ MB\)' ${logs_dir}/${remote_sync_dir}.log | grep -oE '[0-9]+ MB' | grep -oE '[0-9]+')
	if [[ ${full_rsync_exit_code} != "0" ]];then
		rsync_status="1"
	else
		rsync_status=${full_rsync_exit_code}
	fi
	if [[ ! -d ${textfile_collector_dir} ]];then
		mkdir -p ${textfile_collector_dir}
	fi
	cat >${textfile_collector_dir}/promethues.${remote_sync_dir}.prom <<-EOF
	# HELP rsync_status Rsync synchronization status
	# TYPE rsync_status gauge
	rsync_status{dirname="${remote_sync_dir}"} ${rsync_status}
	
	# HELP rsync_total_files_sum The total number of files transferred by rsync
	# TYPE rsync_total_files_sum gauge
	rsync_total_files_sum{dirname="${remote_sync_dir}"} ${rsync_files_num}
	
	# HELP rsync_total_size_mb The total size of files transferred by rsync
	# TYPE rsync_total_size_mb gauge
	rsync_total_size_mb{dirname="${remote_sync_dir}"} ${rsync_files_size}
	
	# HELP rsync_start_time Rsync transmission start time
	# TYPE rsync_start_time gauge
	rsync_start_time{dirname="${remote_sync_dir}"} ${rsync_start_time}
	
	# HELP rsync_duration_time_sec Rsync transmission consumes time
	# TYPE rsync_duration_time_sec gauge
	rsync_duration_time_sec{dirname="${remote_sync_dir}"} ${rsync_duration_time}
	EOF
}

run_tasker(){
	echo "[INFO] Starting scheduled tasks..."
	echo "${cron_exp} echo runcron >${work_dir}/logs/runcron" > ${work_dir}/etc/tasker.conf
	echo "00 23 * * * rm -rf ${logs_dir}/\$(date -d \"-7 day\" +%Y-%m-%d)_*" >> ${work_dir}/etc/tasker.conf
	${work_dir}/bin/tasker -file ${work_dir}/etc/tasker.conf -verbose
	if [[ $? != 0 ]];then
		echo "[ERROR] Scheduled task start failed"
		exit 111
	fi
}

inotify_fun(){

	cd ${sync_dir}
	if [[ -n ${exclude_file} ]];then
		echo "[INFO] Start monitor ${sync_dir}"
		inotifywait --exclude "${exclude_file}" -mrq --timefmt "%y-%m-%d_%H:%M:%S" --format "%T %Xe %w%f" -e create,delete,close_write,move ./ | while read time event file
		do
			case ${event} in
			DELETEXISDIR|MOVED_FROMXISDIR|MOVED_TOXISDIR|CREATEXISDIR)
				echo "${time};${sync_dir};${module_name};${remote_sync_dir};${event};${file};" >> ${logs_dir}/inotify-dir.log
			;;
			CREATE|ATTRIB|CLOSE_WRITEXCLOSE|MOVED_TO|DELETE|MOVED_FROM)
				echo "${time};${sync_dir};${module_name};${remote_sync_dir};${event};${file};" >> ${logs_dir}/inotify-file.log
			;;
			esac
		done
	else
		
		inotifywait -mrq --timefmt "%y-%m-%d_%H:%M:%S" --format "%T %Xe %w%f" -e create,delete,close_write,move ./ | while read time event file
		do
			case ${event} in
			DELETEXISDIR|MOVED_FROMXISDIR|MOVED_TOXISDIR|CREATEXISDIR)
				echo "${time};${sync_dir};${module_name};${remote_sync_dir};${event};${file};" >> ${logs_dir}/inotify-dir.log
			;;
			CREATE|ATTRIB|CLOSE_WRITEXCLOSE|MOVED_TO|DELETE|MOVED_FROM)
				echo "${time};${sync_dir};${module_name};${remote_sync_dir};${event};${file};" >> ${logs_dir}/inotify-file.log
			;;
			esac
		done
	fi
	if [[ $? != 0 ]];then
		echo "[ERROR] Failed to start listening directory ${sync_dir}"
	fi
}

rsync_fun(){
	while true
	do
		currentDate=$(date +%Y-%m-%d)
		sleep ${real_time_sync_delay}
		tmpdir=$(mktemp -d -p ${logs_dir})
		if [[ -s ${logs_dir}/inotify-file.log ]];then
			\mv ${logs_dir}/inotify-file.log ${tmpdir}/inotify-file-tmp.log
		fi
		if [[  -s ${logs_dir}/inotify-dir.log ]];then
			\mv ${logs_dir}/inotify-dir.log ${tmpdir}/inotify-dir-tmp.log
		fi
		if [[ ! -s ${tmpdir}/inotify-file-tmp.log && ! -s ${tmpdir}/inotify-dir-tmp.log ]];then
			rm -rf "${tmpdir}"
			continue
		fi
		
		if [[ -s ${tmpdir}/inotify-file-tmp.log ]];then
			##获取针对文件的事件并保留最新事件
			awk -F ';' '{a[$6]=$0}END{for(i in a){print a[i]}}' ${tmpdir}/inotify-file-tmp.log > ${tmpdir}/file-tmp.txt
		fi
		if [[  -s ${tmpdir}/inotify-dir-tmp.log ]];then
			##获取针对目录的事件并保留最新事件
			awk -F ';' '{a[$6]=$0}END{for(i in a){print a[i]}}' ${tmpdir}/inotify-dir-tmp.log > ${tmpdir}/dir-tmp.txt
		fi
		###START去除重复数据以及不必要的事件
		if [[ -s ${tmpdir}/dir-tmp.txt ]];then
			\cp ${tmpdir}/dir-tmp.txt ${tmpdir}/dir-exe.txt
			##删除存在子目录关系的数据，保留父目录
			while read line
			do
				basedir=$(echo "${line}" | awk -F ';' '{print$6}' | xargs basename )
				parentdir=$(echo "${line}" | awk -F ';' '{print$6}' | xargs dirname | xargs basename )
				if [[ ${parentdir} != "." ]];then
					grep -E "${parentdir};$" ${tmpdir}/dir-tmp.txt && sed -i "/${parentdir}.${basedir};$/d" ${tmpdir}/dir-exe.txt
				fi
			done < ${tmpdir}/dir-tmp.txt
		fi
		if [[ -s ${tmpdir}/file-tmp.txt ]];then
			\cp ${tmpdir}/file-tmp.txt ${tmpdir}/file-exe.txt
		fi
		if [[ -s ${tmpdir}/file-tmp.txt && -s ${tmpdir}/dir-tmp.txt ]];then
			##删除已经有目录事件所对应的文件事件
			while read line
			do
				basedir=$(echo "${line}" | awk -F ';' '{print$6}' | xargs basename )
				sed -i "/${basedir}/d" ${tmpdir}/file-exe.txt
			done < ${tmpdir}/dir-exe.txt
			###END去除重复数据以及不必要的事件
		fi
		###START逐行对变化的文件目录同步到rsynd服务端
		fifo_file=rsync.pipe
		##创建管道符
		mkfifo ${fifo_file}
		##绑定管道符
		exec 5<>${fifo_file}
		rm ${fifo_file}
		##初始化任务队列
		real_time_sync_parallel_num=${real_time_sync_parallel_num:-10}
		for ((i=0;i<${real_time_sync_parallel_num};i++))
		do
			echo ""
		done >&5
		while read line
		do
			read -u 5
			{
				sersync_call
				echo "" >&5
			} &
		done < <( cat ${tmpdir}/dir-exe.txt ${tmpdir}/file-exe.txt 2>/dev/null)
		##等待所有子进程执行完毕
		wait
		##关闭任务队列
		exec 5>&-
		###END逐行对变化的文件目录同步到rsynd服务端
		cat ${tmpdir}/dir-exe.txt ${tmpdir}/file-exe.txt 2>/dev/null >>${logs_dir}/${currentDate}_rsync_history.log
		rm -rf ${tmpdir}
	done
}

sersync_call(){

	sync_dir=$(echo ${line} | awk -F ';' '{print$2}')
	module_name=$(echo ${line} | awk -F ';' '{print$3}')
	remote_sync_dir=$(echo ${line} | awk -F ';' '{print$4}')
	event=$(echo ${line} | awk -F ';' '{print$5}')
	file=$(echo "${line}" | awk -F ';' '{print$6}' | sed -e 's/[]`!@#$%^&*(){}|\;:<>,. []/\\&/g')
	##对变化的文件或者文档循环同步到不同的rsynd服务端
	for ipaddr in ${sync_dir_module_ip[${sync_dir}]}
	do
		rsync_date=$(date +%Y-%m-%d)
		rsyncd_ip=$(echo ${ipaddr} | awk -F ':' '{print$1}')
		rsyncd_port=$(echo ${ipaddr} | awk -F ':' '{print$2}')
		rsyncd_port=${rsyncd_port:-873}
		lockfile=$(echo -n "${file}${rsyncd_ip}" | md5sum | awk '{print $1}')
		###声明变量用于子进程引用
		export rsyncd_ipaddr=${rsyncd_ip}
		export remote_sync_dir=${remote_sync_dir}
		##对rsync操作使用flock加锁防止多个周期一个文件重复同步造成IO阻塞
		flock -n -x ${logs_dir}/${lockfile} -c "
		${work_dir}/bin/sersync.sh  -m ${module_name} -u ${rsync_user} \
		--rsyncd-ip ${rsyncd_ip} --rsyncd-port ${rsyncd_port} --passwd-file ${rsync_passwd_file} \
		--rsync-root-dir ${sync_dir} --rsync-remote-dir ${remote_sync_dir} -f ${file} \
		--event ${event} --rsync-timeout ${real_time_rsync_timeout} \
		--rsync-bwlimit ${rsync_bwlimit} --rsync-extra-args \
		\"${extra_rsync_args} --backup --backup-dir=/history-backup/${remote_sync_dir}/${rsync_date}\" \
		--rsync-command-path ${work_dir}/bin/rsync.sh;rm -rf ${logs_dir}/${lockfile}"
	done
}

run_ctl(){
	
	###声明变量用于子进程存储日志
	export logs_dir=${work_dir}/logs
	###创建日志目录
	if [[ ! -d ${logs_dir} ]];then
		mkdir -p ${logs_dir}
	fi
	###创建临时空目录
	if [[ ! -d ${logs_dir}/empty ]];then
		mkdir -p ${logs_dir}/empty
	else
		rm -rf ${logs_dir}/empty/*
	fi
	###定义关联数组
	declare -A sync_dir_module_ip
	sync_dir_module_ip=""

	for d in ${listen_dir[@]}
	do
		remote_sync_dir=$(echo ${d} | awk -F '=' '{print$1}')
		sync_dir=$(echo ${d} | awk -F '=' '{print$2}')
		if [[ ! -d ${sync_dir} ]];then
			echo "[ERROR] No such file or directory ${sync_dir}"
			exit
		fi
		###获取当前目录监听排除
		for e in ${exclude_file_rule[@]}
		do
			exclude_file=$(echo ${e} | grep -o "${sync_dir}=.*" | awk -F '=' '{print$2}')
			[[ ! -z ${exclude_file} ]] && break
		done
		###获取当前目录执行脚本
		for r in ${exec_command_list[@]}
		do
			exec_shell_file=$(echo ${r} | grep -o "${sync_dir}=.*" | awk -F '=' '{print$2}')
			[[ ! -z ${exec_shell_file} ]] && break
		done
		###获取当前目录所对应的模块名称和模块ip
		for m in ${rsyncd_mod[@]}
		do
			module_name=$(echo ${m} | grep -o ".*${sync_dir}" | awk -F '=' '{print$1}')
			[[ -z ${module_name} ]] && continue
			module_ip_list=$(echo ${rsyncd_ip[@]} | grep -oE "${module_name}=[0-9\.\,\:]{1,}" | awk -F = '{print$2}')
			[[ ! -z ${module_name} ]] && break
		done
		[[ -z ${module_name} ]] && continue
		sync_dir_module_ip[${sync_dir}]="$(echo ${module_ip_list} | sed 's/,/ /g')"
		if [[ ${full_rsync_first_enable} = "1" ]];then
			full_rsync_first &
		fi
		if [[ ${full_rsync_enable} = "1" ]];then
			full_rsync_fun &
		fi
		if [[ ${real_time_sync_enable} = "1" ]];then
			echo "[INFO] Start monitor ${sync_dir}"
			inotify_fun &
		fi
	done

	if [[ ${real_time_sync_enable} = "1" ]];then
		rsync_fun &
	fi
	if [[ ${full_rsync_enable} = "1" ]];then
		run_tasker &
	fi
 
}

keep_foreground(){
	tail -f /dev/null
}


program=$(basename $0)
#-o或--options选项后面接可接受的短选项，如ex:s::，表示可接受的短选项为-e -x -s，其中-e选项不接参数，-x选项后必须接参数，-s选项的参数为可选的
#-l或--long选项后面接可接受的长选项，用逗号分开，冒号的意义同短选项。
#-n选项后接选项解析错误时提示的脚本名字["std.sh: unknown option -- d"]
ARGS=$(getopt -a -o f: -n "${program}" -- "$@")

#如果参数不正确，打印提示信息
[[ $? -ne 0 ]] && usage && exit 1
[[ $# -eq 0 ]] && usage && exit 1

echo ${ARGS} | grep -qE '\-f'
[[ $? -ne 0 ]] && usage && exit 1

eval set -- "${ARGS}"
while true
do
	case "$1" in
		-f)
			config_file="$2"
			if [[ ! -f ${config_file} ]];then
				echo "[ERROR] No such file or directory ${config_file}"
			else
				. ${config_file} || exit
			fi
			shift 2
			;;
		--)
			shift
			break
			;;
		*)
			echo usage
			break
			;;
	esac
done

run_ctl
keep_foreground
