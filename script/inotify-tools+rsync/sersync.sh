#!/bin/bash
# 脚本本为调用rsync同步
rsync_passwd_file=/etc/rsync.pas
# 临时目录
rsync_tmp_dir=/tmp/rsync-tmp
# 错误日志
rsync_err_file=rsync-err.log
# rsyncd端地址
des_ip=(192.168.74.20)
# rsync定义的验证用户名
user=rsync
# 配置同步超时时间秒,防止意外并发
rsync_timeout=300

rysnc_fun(){
	# 参数赋值
	sync_dir="$1"
	module_name="$2"
	event="$3"
	file="$4"

	for remote_ip in ${des_ip[@]}
	do
		case $event in
		CREATE|ATTRIB|CLOSE_WRITEXCLOSE|MOVED_TO|MOVED_TOXISDIR|CREATEXISDIR)
			cd ${sync_dir} && \
			timeout ${rsync_timeout} rsync -au -R --password-file=${rsync_passwd_file} "${file}" ${user}@${remote_ip}::${module_name} 2>>${rsync_tmp_dir}/${rsync_err_file}
		;;
		DELETE|MOVED_FROM|DELETEXISDIR|MOVED_FROMXISDIR)
			full_file_dir=`echo ${file} | sed 's/.\///'`
			file_dir=`echo ${file} | sed 's/.\///'`
			i=0
			include_file=$(echo -n "${file}" | md5sum | awk '{print $1}')

			#获取--include参数
			while true
			do
				dirname=$(dirname $file_dir | head -1)
				if [[ $dirname != '.' ]];then
					include[$i]=$dirname
					file_dir=$dirname
					echo "${include[$i]}">>${rsync_tmp_dir}/${include_file}
				else
					if [[ $event = 'DELETEXISDIR' || $event = 'MOVED_FROMXISDIR' ]];then
						#目录被删除时，同时删除目录下的所有文件
						include[$i]=${full_file_dir}/***
					else
						include[$i]=${full_file_dir}
					fi
					echo "${include[$i]}">>${rsync_tmp_dir}/${include_file}
					break
				fi
				((i++))
			done
			cd ${sync_dir} && \
			timeout ${rsync_timeout} rsync -au -R --delete ./ --password-file=${rsync_passwd_file} --include-from=${rsync_tmp_dir}/${include_file} --exclude="*" ${user}@${remote_ip}::${module_name} 2>>${rsync_tmp_dir}/${rsync_err_file}
			rm -rf ${rsync_tmp_dir}/${include_file}
		;;
		esac
	done
}

if [[ ! -d $rsync_tmp_dir ]];then
	mkdir $rsync_tmp_dir
fi

rysnc_fun "$1" "$2" "$3" "$4"

