#!/bin/bash
usage()
{
	cat <<-EOF
	Usage:${program} [OPTION]...
	-f   指定配置文件
	EOF
}

full_rsync_first(){

	if [[ ! -d ${sync_dir} ]];then
		echo "[ERROR] No such file or directory ${sync_dir}"
		exit
	else
		cd ${sync_dir}
	fi
	
	for ipaddr in ${sync_dir_module_ip[${sync_dir}]}
	do
		rsyncd_ip=$(echo ${ipaddr} | awk -F ':' '{print$1}')
		rsyncd_port=$(echo ${ipaddr} | awk -F ':' '{print$2}')
		lockfile=$(echo -n "${sync_dir}${rsyncd_ip}" | md5sum | awk '{print $1}')
		echo "[INFO] Syncing ${sync_dir} in full to ${ipaddr}..."
		flock -n -x ${logs_dir}/${lockfile} -c "
		timeout ${full_rsync_timeout}h ls -1 |xargs -P 3 -n 3 -I % \
		rsync -rlptDRu --delete --port=${rsyncd_port} ${extra_rsync_args} \
		--bwlimit=${rsync_bwlimit} --password-file=${rsync_passwd_file} % \
		${rsync_user}@${rsyncd_ip}::${module_name}/${remote_sync_dir} && \
		echo \"[INFO] Full sync ${sync_dir} complete to ${ipaddr}\" || \
		echo \"[ERROR] Error in full sync ${sync_dir} to ${ipaddr}\";\
		rm -rf ${logs_dir}/${lockfile}"
	done

}


full_rsync_fun(){

	if [[ ! -d ${sync_dir} ]];then
		echo "[ERROR] No such file or directory ${sync_dir}"
		exit
	else
		cd ${sync_dir}
	fi

	while true
	do
		sleep ${full_rsync_interval}d
		while true
		do
			if [[ "23 00 01 02 03 04" =~ `date +'%H'` ]];then
				for ipaddr in ${sync_dir_module_ip[${sync_dir}]}
				do
					rsyncd_ip=$(echo ${ipaddr} | awk -F ':' '{print$1}')
					rsyncd_port=$(echo ${ipaddr} | awk -F ':' '{print$2}')
					lockfile=$(echo -n "${sync_dir}${rsyncd_ip}" | md5sum | awk '{print $1}')
					echo "[INFO] Syncing ${sync_dir} in full to ${ipaddr}..."
					flock -n -x ${logs_dir}/${lockfile} -c "
					timeout ${full_rsync_timeout}h ls -1 |xargs -P 3 -n 3 -I % \
					rsync -rlptDRu --delete --port=${rsyncd_port} ${extra_rsync_args} \
					--bwlimit=${rsync_bwlimit} --password-file=${rsync_passwd_file} % \
					${rsync_user}@${rsyncd_ip}::${module_name}/${remote_sync_dir} && \
					echo \"[INFO] Full sync ${sync_dir} complete to ${ipaddr}\" || \
					echo \"[ERROR] Error in full sync ${sync_dir} to ${ipaddr}\";\
					rm -rf ${logs_dir}/${lockfile}"
				done
				break
			else
				sleep 1h
			fi
		done
	done

}

inotify_fun(){

	if [[ ! -d ${sync_dir} ]];then
		echo "[ERROR] No such file or directory ${sync_dir}"
		exit
	else
		cd ${sync_dir}
	fi

	if [[ -n ${exclude_file} ]];then
		echo "[INFO] Start monitor ${sync_dir}"
		inotifywait --exclude "${exclude_file}" -mrq --timefmt "%y-%m-%d_%H:%M:%S" --format "%T %Xe %w%f" -e create,delete,attrib,close_write,move ./ | while read time event file
		do
			echo "${time};${sync_dir};${module_name};${event};${file};" >> ${logs_dir}/inotify-file.log
		done || echo "[ERROR] Failed to monitor ${sync_dir}"
	else
		
		inotifywait -mrq --timefmt "%y-%m-%d_%H:%M:%S" --format "%T %Xe %w%f" -e create,delete,attrib,close_write,move ./ | while read time event file
		do
			echo "${time};${sync_dir};${module_name};${event};${file}" >> ${logs_dir}/inotify-file.log
		done || echo "[ERROR] Failed to monitor ${sync_dir}"
	fi
}

rsync_fun(){
	while true
	do
		sleep 20
		if [[ -s ${logs_dir}/inotify-file.log ]];then
			\mv ${logs_dir}/inotify-file.log ${logs_dir}/inotify-tmp.log
			##对重复文件的事件去重并保留最新的事件类型
			awk -F ';' '{a[$5]=$0}END{for(i in a){print a[i]}}' ${logs_dir}/inotify-tmp.log > ${logs_dir}/inotify-exe.log
			while read line
			do
				
				sleep 0.05
				sync_dir=$(echo ${line} | awk -F ';' '{print$2}')
				module_name=$(echo ${line} | awk -F ';' '{print$3}')
				event=$(echo ${line} | awk -F ';' '{print$4}')
				file=$(echo "${line}" | awk -F ';' '{print$5}' | sed -e 's/[] ()$*^[]/\\&/g')
				##对rsync操作加锁防止多个周期一个文件重复同步
				for ipaddr in ${sync_dir_module_ip[${sync_dir}]}
				do
					rsyncd_ip=$(echo ${ipaddr} | awk -F ':' '{print$1}')
					rsyncd_port=$(echo ${ipaddr} | awk -F ':' '{print$2}')
					lockfile=$(echo -n "${file}${rsyncd_ip}" | md5sum | awk '{print $1}')
					flock -n -x ${logs_dir}/${lockfile} -c "${work_dir}/bin/sersync.sh  -m ${module_name} -u ${rsync_user} --rsyncd-ip ${rsyncd_ip} --rsyncd-port ${rsyncd_port} --passwd-file ${rsync_passwd_file} --rsync-root-dir ${sync_dir} --rsync-remote-dir ${remote_sync_dir} -f ${file} --logs-dir ${logs_dir} -e ${event} --rsync-timeout ${rsync_timeout} --rsync-bwlimit ${rsync_bwlimit} --rsync-extra-args \"${extra_rsync_args}\";rm -rf ${logs_dir}/${lockfile}" &
				done
			done < ${logs_dir}/inotify-exe.log
		fi
	done
}

run_ctl(){
	if [[ ! -d ${logs_dir} ]];then
		mkdir -p ${logs_dir}
	fi
	declare -A sync_dir_module_ip
	sync_dir_module_ip=""

	for d in ${listen_dir[@]}
	do
		remote_sync_dir=$(echo ${d} | awk -F '=' '{print$1}')
		sync_dir=$(echo ${d} | awk -F '=' '{print$2}')
		###获取当前目录监听排除
                for e in ${exclude_file_rule[@]}
                do
                        exclude_file=$(echo ${e} | grep -o "${sync_dir}=.*" | awk -F '=' '{print$2}')
			[[ ! -z ${exclude_file} ]] && break
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
	rsync_fun
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
[[ $? -ne 0 ]] && echo 缺少参数 && usage && exit 1

eval set -- "${ARGS}"
while true
do
	case "$1" in
		-f)
			config_file="$2"
			if [[ ! -f ${config_file} ]];then
				echo error
			else
				. ${config_file}
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


