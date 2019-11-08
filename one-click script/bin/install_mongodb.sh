#!/bin/bash
. ./public.sh
. ./install_version.sh
mongodb_install_set(){
	if [[ ${os_bit} = '32' ]];then
		diy_echo "该版本不支持32位系统" "${red}" "${error}"
		exit 1
	fi
	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'
	input_option '请输入本机部署个数' '1' 'deploy_num'
	input_option '请输入起始端口号' '27017' 'mongodb_port'
	input_option '请输入数据存储路径' '/data' 'mongodb_data_dir'
	mongodb_data_dir=${input_value}
}

mongodb_install(){
	mv ${tar_dir}/* ${home_dir}
	mkdir -p ${home_dir}/etc
	mkdir -p ${mongodb_data_dir}
	mongodb_config
	add_mongodb_service
}

mongodb_config(){
	conf_dir=${home_dir}/etc
	cat >${conf_dir}/mongodb.conf<<-EOF
	#端口号
	port = 27017
	bind_ip=0.0.0.0
	#数据目录
	dbpath=
	#日志目录
	logpath=
	fork = true
	#日志输出方式
	logappend = true
	#开启认证
	#auth = true
	EOF
	sed -i "s#port.*#port = ${mongodb_port}#" ${conf_dir}/mongodb.conf
	sed -i "s#dbpath.*#dbpath = ${mongodb_data_dir}#" ${conf_dir}/mongodb.conf
	sed -i "s#logpath.*#logpath = ${home_dir}/logs/mongodb.log#" ${conf_dir}/mongodb.conf
	add_sys_env "PATH=\${home_dir}/bin:\$PATH"
	add_log_cut mongodb ${home_dir}/logs/mongodb.log
}

add_mongodb_service(){
	ExecStart="${home_dir}/bin/mongod -f ${home_dir}/etc/mongodb.conf"
	ExecStop="${home_dir}/bin/mongod -f ${home_dir}/etc/mongodb.conf"
	conf_system_service
	add_sys_env "PATH=${home_dir}/bin:\$PATH"
	add_system_service mongodb ${home_dir}/mongodb_init
}


install_version mongodb
install_selcet
mongodb_install_set
install_dir_set
download_unzip
mongodb_install
clear_install

