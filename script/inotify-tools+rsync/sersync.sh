#!/bin/bash
# 脚本本为调用rsync同步
rsync_passwd_file=/etc/rsync.pas
des_ip=(192.168.74.20)
# rsync --daemon定义的验证用户名
user=rsync

rysnc_fun(){
	# 参数赋值
	sync_dir=$1
	module_name=$2
	event=$3
	file=$4

	for remote_ip in ${des_ip[@]}
	do
		case $event in
		CREATE|ATTRIB|CLOSE_WRITEXCLOSE|MOVED_TO|MOVED_TOXISDIR|CREATEXISDIR)
			cd ${sync_dir} && rsync -au -R --password-file=${rsync_passwd_file} ${file} ${user}@${remote_ip}::${module_name} >/dev/null 2>&1 &
		;;
		DELETE|MOVED_FROM|DELETEXISDIR|MOVED_FROMXISDIR)
			full_file_dir=`echo ${file} | sed 's/.\///'`
			file_dir=`echo ${file} | sed 's/.\///'`
			include=
			while true
			do
				dirname="`dirname $file_dir`"
				if [[ $dirname != '.' ]];then
					include="--include=$dirname $include"
					file_dir=$dirname
				else
					if [[ $event = 'DELETEXISDIR' || $event = 'MOVED_FROMXISDIR' ]];then
						include="$include --include=${full_file_dir}/***"
					else
						include="$include --include=${full_file_dir}"
					fi
					break
				fi
			done
			cd ${sync_dir} && rsync -au -R --delete ./ --password-file=${rsync_passwd_file} ${include} --exclude="*" ${user}@${remote_ip}::${module_name} >/dev/null 2>&1 &
		;;
		esac
	done
}

rysnc_fun $1 $2 $3 $4
