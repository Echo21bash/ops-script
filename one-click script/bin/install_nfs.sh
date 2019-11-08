#install fastdfs script
fastdfs_install_set(){
	output_option '安装模式' '单机 集群' 'deploy_mode'
	output_option '安装的模块' 'tracker storage' 'install_module'
	input_option '请输入文件存储路径' '/data/fdfs' 'file_dir'
	file_dir=${input_value}
	input_option '请输入tracker端口' '22122' 'tracker_port'
	input_option '请输入storage端口' '23000' 'storage_port'

}

fastdfs_install(){
	yum install gcc -y
	cd ${tar_dir}
	diy_echo "正在安装相关依赖..." "" "${info}"
	wget https://codeload.github.com/happyfish100/libfastcommon/tar.gz/master -O libfastcommon-master.tar.gz && tar -zxf libfastcommon-master.tar.gz
	cd libfastcommon-master
	#libfastcommon安装目录配置
	sed -i "/^TARGET_PREFIX=$DESTDIR/i\DESTDIR=${home_dir}" ./make.sh
	sed -i 's#TARGET_PREFIX=.*#TARGET_PREFIX=$DESTDIR#' ./make.sh
	./make.sh  && ./make.sh install
	if [[ $? = '0' ]];then
		diy_echo "libfastcommon安装完成." "" "${info}"
	else
		diy_echo "libfastcommon安装失败." "${yellow}" "${error}"
		exit
	fi
	ln -sfn ${home_dir}/include/fastcommon /usr/include
	ln -sfn ${home_dir}/lib64/libfastcommon.so /usr/lib/libfastcommon.so
	ln -sfn ${home_dir}/lib64/libfastcommon.so /usr/lib64/libfastcommon.so
	#fastdfs安装目录配置
	cd ${tar_dir}
	sed -i "/^TARGET_PREFIX=$DESTDIR/i\DESTDIR=${home_dir}" ./make.sh
	sed -i 's#TARGET_PREFIX=.*#TARGET_PREFIX=$DESTDIR#' ./make.sh
	sed -i 's#TARGET_CONF_PATH=.*#TARGET_CONF_PATH=$DESTDIR/etc#' ./make.sh
	sed -i 's#TARGET_INIT_PATH=.*#TARGET_INIT_PATH=$DESTDIR/etc/init.d#' ./make.sh

	diy_echo "正在安装fastdfs服务..." "" "${info}"
		./make.sh && ./make.sh install
	if [[ $? = '0' ]];then
		diy_echo "fastdfs安装完成." "" "${info}"
	else
		diy_echo "fastdfs安装失败." "${yellow}" "${error}"
		exit
	fi
	ln -sfn ${home_dir}/include/fastdfs /usr/include
	ln -sfn ${home_dir}/lib64/libfdfsclient.so /usr/lib/libfdfsclient.so
	ln -sfn ${home_dir}/lib64/libfdfsclient.so /usr/lib64/libfdfsclient.so

}

fastdfs_config(){
	mkdir -p ${file_dir}
	cp ${home_dir}/etc/tracker.conf.sample ${home_dir}/etc/tracker.conf
	cp ${home_dir}/etc/storage.conf.sample ${home_dir}/etc/storage.conf
	cp ${home_dir}/etc/client.conf.sample ${home_dir}/etc/client.conf
	get_ip
	sed -i "s#base_path=.*#base_path=${file_dir}#" ${home_dir}/etc/client.conf
	sed -i "s#tracker_server=.*#tracker_server=${local_ip}:${tracker_port}#" ${home_dir}/etc/client.conf

	sed -i "s#port=23000#port=${storage_port}#" ${home_dir}/etc/storage.conf
	sed -i "s#base_path=.*#base_path=${file_dir}#" ${home_dir}/etc/storage.conf
	sed -i "s#store_path0=.*#store_path0=${file_dir}#" ${home_dir}/etc/storage.conf
	sed -i "s#tracker_server=.*#tracker_server=${local_ip}:${tracker_port}#" ${home_dir}/etc/storage.conf

	sed -i "s#port=22122#port=${tracker_port}#" ${home_dir}/etc/tracker.conf
	sed -i "s#base_path=.*#base_path=${file_dir}#" ${home_dir}/etc/tracker.conf
	add_log_cut fastdfs ${file_dir}/logs/*.log
	add_sys_env "PATH=${home_dir}/bin:\$PATH"
}

add_fastdfs_service(){

	ExecStart="${home_dir}/bin/fdfs_trackerd ${home_dir}/etc/tracker.conf start"
	conf_system_service
	add_system_service fdfs_trackerd ${home_dir}/init

	ExecStart="${home_dir}/bin/fdfs_storaged ${home_dir}/etc/storage.conf start"
	conf_system_service
	add_system_service fdfs_storaged ${home_dir}/init

}

fastdfs_install_ctl(){
	install_selcet
	fastdfs_install_set
	install_dir_set fastdfs
	download_unzip 
	fastdfs_install
	fastdfs_config
	add_fastdfs_service
	clear_install
}
