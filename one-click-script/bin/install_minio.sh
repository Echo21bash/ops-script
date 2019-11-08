#!/bin/bash
. ./public.sh
. ./install_version.sh
minio_install_set(){
	output_option "请选择安装模式" "单机模式 集群模式" "deploy_mode"
	input_option "请输入minio端口" "9000" "minio_port"
	input_option "请输入minio存储路径" "/data/minio" "data_dir"
	data_dir=${input_value}
	input_option "请输入minio账号key(>=3位)" "minio" "minio_access"
	minio_access=${input_value}
	input_option "请输入minio认证key(8-40位)" "12345678" "minio_secret"
	minio_secret=${input_value}
}

minio_config(){
	mkdir -p ${home_dir}/{bin,etc}
	mkdir -p ${data_dir}
	mv ${install_dir}/minio-release ${home_dir}/bin/minio
	chmod +x ${home_dir}/bin/minio
	cat >${home_dir}/etc/minio<<-EOF
	MINIO_ACCESS_KEY=${minio_access}
	MINIO_SECRET_KEY=${minio_secret}
	MINIO_VOLUMES=${data_dir}
	MINIO_OPTS="-C ${home_dir}/etc --address :${minio_port}"
	EOF
	add_sys_env "PATH=${home_dir}/bin:\$PATH"
}

add_minio_service(){
	EnvironmentFile="${home_dir}/etc/minio"
	WorkingDirectory="${home_dir}"
	ExecStart="${home_dir}/bin/minio server \$MINIO_OPTS \$MINIO_VOLUMES"
	#ARGS="&"
	conf_system_service
	add_system_service minio ${home_dir}/init
}


install_selcet
minio_install_set
install_dir_set minio
download_unzip
minio_config
add_minio_service
service_control minio

