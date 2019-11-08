#nginx install script
nginx_install_set(){
	input_option '是否添加额外模块' 'n' 'add'
	add=${input_value}
	yes_or_no ${add}
	if [[ $? = '0' ]];then
		output_option '选择要添加的模块' 'fastdfs-nginx-module' 'add_module'
		add_module_value=${output_value}
	fi
}

nginx_install(){

	#安装编译工具及库文件
	echo -e "${info} 正在安装编译工具及库文件..."
	yum -y install make zlib zlib-devel gcc-c++ libtool  openssl openssl-devel pcre pcre-devel
	if [ $? = "0" ];then
		echo -e "${info} 编译工具及库文件安装成功."
	else
		echo -e "${error} 编译工具及库文件安装失败请检查!!!" && exit 1
	fi
	useradd -M -s /sbin/nologin nginx
}

nginx_compile(){
	cd ${tar_dir}
	if [[ x${add_module} = 'x' ]];then
		./configure --prefix=${home_dir} --group=nginx --user=nginx --with-http_stub_status_module --with-http_ssl_module --with-http_gzip_static_module --with-pcre --with-stream --with-stream_ssl_module
	else
		wget https://codeload.github.com/happyfish100/fastdfs-nginx-module/zip/master -O fastdfs-nginx-module-master.zip && unzip -o fastdfs-nginx-module-master.zip
		./configure --prefix=${home_dir} --group=nginx --user=nginx --with-http_stub_status_module --with-http_ssl_module --with-http_gzip_static_module --with-pcre --with-stream --with-stream_ssl_module --add-module=${tar_dir}/${add_module_value}-master/src
		#sed -i 's///'
	fi
	make && make install
	if [ $? = "0" ];then
		echo -e "${info} nginx安装成功."
	else
		echo -e "${error} nginx安装失败!!!"
		exit 1
	fi

}

nginx_config(){
	conf_dir=${home_dir}/conf
	cat >/tmp/nginx.tmp<<EOF
    server_names_hash_bucket_size 128;
    large_client_header_buffers 4 32k;
    client_header_buffer_size 32k;
    client_max_body_size 100m;
    client_header_timeout 120s;
    client_body_timeout 120s;
	 
    proxy_buffer_size 64k;
    proxy_buffers   4 32k;
    proxy_busy_buffers_size 64k;
    proxy_connect_timeout 120s;
    proxy_send_timeout 120s;
    proxy_read_timeout 120s;
    
	server_tokens off;
    sendfile   on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 60;
     
    gzip  on;
    gzip_min_length 1k;
    gzip_buffers 4 16k;
    gzip_comp_level 3;
    gzip_http_version 1.0;
    gzip_types text/plain application/x-javascript text/css application/xml text/javascript application/x-httpd-php image/jpeg image/gif image/png;
    gzip_vary on;
    gzip_disable "MSIE [1-6]\.";
EOF
	sed -i '/logs\/access.log/,/#gzip/{//!d}' ${conf_dir}/nginx.conf
	sed -i '/#gzip/r /tmp/nginx.tmp' ${conf_dir}/nginx.conf && rm -rf /tmp/nginx.tmp
	add_log_cut nginx ${home_dir}/logs/*.log
}

add_nginx_service(){

	Type="forking"
	ExecStart="${home_dir}/sbin/nginx -c ${home_dir}/conf/nginx.conf"
	ExecReload="${home_dir}/sbin/nginx -s reload"
	ExecStop="${home_dir}/sbin/nginx -s stop"
	conf_system_service
	add_system_service nginx ${home_dir}/init
}

nginx_install_ctl(){

	install_version nginx
	install_selcet
	nginx_install_set
	install_dir_set
	download_unzip
	nginx_install
	nginx_compile
	nginx_config
	add_nginx_service
	clear_install
	
}
