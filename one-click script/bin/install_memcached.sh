#!/bin/bash
. ./public.sh
. ./install_version.sh
memcached_inistall_set(){

	output_option "请选择安装版本" "普通版 集成repcached补丁版" "branch"
	input_option "输入本机部署个数" "1" "deploy_num"
	input_option "输入起始memcached端口号" "11211" "memcached_port"

	if [[ ${branch} = '2' ]];then
		diy_echo "集成repcached补丁,该补丁并非官方发布,目前最新补丁兼容1.4.13" "${yellow}" "${warning}"
		input_option "输入memcached同步端口号" "11210" "syn_port"
	fi
}

memcached_install(){
	diy_echo "正在安装依赖库..." "" "${info}"
	yum -y install make  gcc-c++ libevent libevent-devel
	if [ $? = '0' ];then
		echo -e "${info} 编译工具及库文件安装成功."
	else
		echo -e "${error} 编译工具及库文件安装失败请检查!!!" && exit 1
	fi

	cd ${tar_dir}
	
	if [ ${branch} = '1' ];then
		./configure --prefix=${home_dir} && make && make install
	fi
	if [ ${branch} = '2' ];then
		repcached_url="http://mdounin.ru/files/repcached-2.3.1-1.4.13.patch.gz"
		wget ${repcached_url} && gzip -d repcached-2.3.1-1.4.13.patch.gz && patch -p1 -i ./repcached-2.3.1-1.4.13.patch
		./configure --prefix=${home_dir} --enable-replication && make && make install
	fi
	if [ $? = '0' ];then
		echo -e "${info} memcached编译完成."
	else
		echo -e "${error} memcached编译失败" && exit 1
	fi

	if [ ${deploy_num} = '1'  ];then
		memcached_config
		add_memcached_service
		add_sys_env "PATH=${home_dir}/bin:$PATH"
	fi
	if [[ ${deploy_num} > '1' ]];then
		mv ${home_dir} ${install_dir}/tmp
		for ((i=1;i<=${deploy_num};i++))
		do
			\cp -rp ${install_dir}/tmp ${install_dir}/memcached-node${i}
			home_dir=${install_dir}/memcached-node${i}
			memcached_config
			add_memcached_service
			memcached_port=$((${memcached_port}+1))
		done
		add_sys_env "PATH=${home_dir}/bin:$PATH"
	fi
		
}

memcached_config(){
	mkdir -p ${home_dir}/etc ${home_dir}/logs
	cat >${home_dir}/etc/memcached<<-EOF
	USER="root"
	PORT="11211"
	MAXCONN="1024"
	CACHESIZE="64"
	LOG="-vv >>$home_dir/logs/memcached.log 2>&1"
	OPTIONS=""
	EOF
	sed -i 's/PORT="11211"/PORT="'${memcached_port}'"/' ${home_dir}/etc/memcached
	if [[ ${branch} = '2' ]];then
		sed -i 's/OPTIONS="" /OPTIONS="-x 127.0.0.1 -X '${syn_port}'"/' ${home_dir}/etc/memcached
	fi

}

add_memcached_service(){

	EnvironmentFile="${home_dir}/etc/memcached"
	ExecStart="${home_dir}/bin/memcached -u \$USER -p \$PORT -m \$CACHESIZE -c \$MAXCONN \$LOG \$OPTIONS"
	conf_system_service
	if [[ ${deploy_num} = '1' ]];then
		add_system_service memcached "${home_dir}/init"
	else
		add_system_service memcached-node${i} "${home_dir}/init"
	fi
}

install_version memcached
install_selcet
memcached_inistall_set
install_dir_set
download_unzip
memcached_install
service_control
clear_install