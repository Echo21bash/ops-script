#install vsftp script
ftp_install_set(){
	input_option '是否快速配置vsftp服务' 'y' 'vsftp'
	vsftp=${input_value}
	yes_or_no ${vsftp}
	if [[ $? = 1 ]];then
		diy_echo "已经取消安装.." "${yellow}" "${warning}" && exit 1
	fi
	if [[ -n `ps aux | grep vsftp | grep -v grep` || -d /etc/vsftpd ]];then
		diy_echo "vsftp正在运行中,或者已经安装vsftp!!" "${yellow}" "${warning}"
		input_option '确定要重新配置vsftp吗?' 'y' 'continue'
		continue=${input_value}
		yes_or_no ${continue}
		if [[ $? = 1 ]];then
			diy_echo "已经取消安装.." "${yellow}" "${warning}" && exit 1
		fi
	fi
	input_option '设置ftp默认文件夹' '/data/ftp' 'ftp_dir'
	ftp_dir=${input_value[@]}

	if [[ ! -d ${ftp_dir} ]];then
		mkdir -p ${ftp_dir}  
	fi
	diy_echo "正在配置VSFTP用户,有管理员和普通用户两种角色,管理员有完全权限,普通用户只有上传和下载的权限." "" "${info}"
	input_option '输入管理员用户名' 'admin' 'manager'
	manager=${input_value[@]}
	input_option '输入管理员密码' 'admin' 'manager_passwd'
	manager_passwd=${input_value[@]}
	input_option '输入普通用户用户名' 'user' 'user'
	user=${input_value[@]}
	input_option '输入普通用户密码' 'user' 'user_passwd'
	user_passwd=${input_value[@]}
}

ftp_install(){
	diy_echo "正在安装db包..." "" "${info}"
	if [[ ${os_release} < '7' ]];then
		yum install -y db4-utils
	else
		yum install -y libdb-utils
	fi
	yum install -y vsftpd

}

ftp_config(){
	diy_echo "正在配置vsftp..." "" "${info}"
	id ftp > /dev/null 2>&1
	if [[ $? = '1' ]];then
		useradd -s /sbin/nologin ftp >/dev/null
		usermod -G ftp -d /var/ftp -s /sbin/nologin
	fi
	mkdir -p /etc/vsftpd/vsftpd.conf.d
	cat >/etc/vsftpd/vftpusers<<-EOF
	${manager}
	${manager_passwd}
	${user}
	${user_passwd}
	EOF

	chown -R ftp.ftp ${ftp_dir}
	db_load -T -t hash -f /etc/vsftpd/vftpusers /etc/vsftpd/vftpusers.db

	cat >/etc/vsftpd/vsftpd.conf<<-EOF
	# Example config file /etc/vsftpd/vsftpd.conf
	#
	# The default compiled in settings are fairly paranoid. This sample file
	# loosens things up a bit, to make the ftp daemon more usable.
	# Please see vsftpd.conf.5 for all compiled in defaults.
	#
	# READ THIS: This example file is NOT an exhaustive list of vsftpd options.
	# Please read the vsftpd.conf.5 manual page to get a full idea of vsftpd's
	# capabilities.

	#禁止匿名登陆
	anonymous_enable=NO
	anon_root=${ftp_dir}
	anon_umask=022
	#普通用户只有上传下载权限
	write_enable=YES
	virtual_use_local_privs=NO
	anon_world_readable_only=NO
	anon_upload_enable=YES
	anon_mkdir_write_enable=YES
	local_enable=YES
	#指定ftp路径
	local_root=${ftp_dir}

	local_umask=022
	connect_from_port_20=YES
	allow_writeable_chroot=YES
	reverse_lookup_enable=NO
	xferlog_enable=YES


	#开启ASCII模式传输数据
	ascii_upload_enable=YES
	ascii_download_enable=YES

	ftpd_banner=Welcome to blah FTP service.
	listen=YES
	userlist_enable=YES
	tcp_wrappers=YES

	#开启虚拟账号
	guest_enable=YES
	guest_username=ftp
	pam_service_name=vsftpd.vuser
	user_config_dir=/etc/vsftpd/vsftpd.conf.d

	#开启被动模式
	pasv_enable=YES
	pasv_min_port=40000
	pasv_max_port=40100
	EOF

	cat >/etc/vsftpd/vsftpd.conf.d/${manager}<<-EOF
	anon_umask=022
	write_enable=YES
	virtual_use_local_privs=NO
	anon_world_readable_only=NO
	anon_upload_enable=YES
	anon_mkdir_write_enable=YES
	anon_other_write_enable=YES
	EOF

	cat >/etc/pam.d/vsftpd.vuser<<-EOF
	auth required pam_userdb.so db=/etc/vsftpd/vftpusers
	account required pam_userdb.so db=/etc/vsftpd/vftpusers
	EOF

}

ftp_install_ctl(){
	ftp_install_set
	ftp_install
	ftp_config
	service_control vsftpd.service
}
