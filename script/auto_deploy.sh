#!/bin/bash
###########################################################
#System Required: Centos 6+
#Description: jenkins auto
#Version: 2.0
#                                                        
#                            by---wang2019.1
###########################################################

#需配置服务器免密登录
#服务器的项目包路径
project_dir='/apps/data/war'
#jenkins工作目录
jenkins_work_dir='/root/.jenkins/jobs'
#远程服务器项目包存放路径和备份路径
remote_project_dir='/apps/data/www'
#工程名
#kuaixiu-SYS-Service
#kuaixiu-SYS-Web
#kuaixiu-CRM-Service
#kuaixiu-CRM-Web
#kuaixiu-bus-web
#kuaixiu-bus-service
#kuaixiu-store-service
#kuaixiu-store-web
#kuaixiu-stock-service
#kuaixiu-stock-web
#kuaixiu-finance-service
#kuaixiu-finance-web
#kuaixiu-statistics-service
#kuaixiu-statistics-web
#统一转换为小写

#原本工程名
original_project_name="$1"
#将工程名统一转换为小写
lower_case_project_name=$(echo $1 | tr [A-Z] [a-z])
#工程名
project_name=${lower_case_project_name}

#服务器ip
server=('172.26.32.172' '172.26.32.173')
#服务器用户
server_user=('root' 'root')
#服务器ssh端口
server_port=('52233' '52233')
#远程服务器项目路径
remote_www_dir='/apps/www'
#日期
deploy_data=$(date +"%Y-%m-%d")

edit_war(){
	cd ${project_dir}
	cp WEB-INF/lib/ibase4j-common.jar WEB-INF/lib/ibase4j-common-3.5.6.jar
	zip -m ${project_dir}/${project_file_name} WEB-INF/lib/ibase4j-common-3.5.6.jar
}

#$1服务器数组序号
send_file(){
	scp -P ${server_port[$server_num]} -r ${project_dir}/${project_file_name} ${server_user[$server_num]}@${server[$server_num]}:${remote_project_dir}/${project_file_name}
	if [[ $? = '0' ]];then
		echo "[INFO]  发送${project_dir}/${project_file_name}完成"
	else
		echo "[ERROR]  发送${project_dir}/${project_file_name}失败"
		exit 1
	fi
}

auto_back(){

	ssh -p ${server_port[$server_num]} ${server_user[$server_num]}@${server[$server_num]}<<EOF
	#备份
	if [[ ! -f ${remote_project_dir}/${back_file_name} ]];then
		cd ${back_file_dir}
		tar zcf ${back_file_name} ${back_file}
		mv ${back_file_name} ${remote_project_dir}
		if [[ $? = '0' ]];then
			echo "[INFO] ${back_file_name}备份完成,路径为${remote_project_dir}"
		fi
	else
		echo "[INFO] ${back_file_name}已经存在备份,路径为${remote_project_dir}"
	fi
EOF
}

auto_deploy(){

	ssh -p ${server_port[$server_num]} ${server_user[$server_num]}@${server[$server_num]}<<EOF
	#停止并清空
	if [ -n ${service_name} ];then
		echo "[INFO] 正在停止${service_name}"
		systemctl stop ${service_name}
		sleep 5
	fi
	rm -rf ${deploy_dir}/*
	echo "[INFO] 正在解压${deploy_file_path}...到${deploy_dir}"
	unzip -oq ${deploy_file_path} -d ${deploy_dir} || tar -zxf ${deploy_file_path} -C ${deploy_dir}
	chmod -R 755 ${deploy_dir}
	#启动
	if [ -n ${service_name} ];then
		echo "[INFO] 正在启动${service_name}"
		systemctl start ${service_name}
	fi

EOF
	if [[ $? = '0' ]];then
		echo "[INFO] 自动部署${project_name}完成"
	else
		echo "[ERROR] 自动部署${project_name}失败"
		exit 1
	fi
}

#区分服务器
case "${project_name}" in
	kuaixiu-bus-web|kuaixiu-bus-service|\
	kuaixiu-stock-web|kuaixiu-stock-service|\
	kuaixiu-crm-web|kuaixiu-crm-service|\
	kuaixiu-statistics-web|kuaixiu-statistics-service|\
	kuaixiu-pc|kuaixiu-gw)
		server_num=0
	;;
	kuaixiu-sys-web|kuaixiu-sys-service|\
	kuaixiu-finance-web|kuaixiu-finance-service|\
	kuaixiu-store-web|kuaixiu-store-service)
		server_num=1
	;;
esac
#区分项目类型
case "${project_name}" in
	kuaixiu-bus-web|kuaixiu-bus-service|\
	kuaixiu-stock-web|kuaixiu-stock-service|\
	kuaixiu-crm-web|kuaixiu-crm-service|\
	kuaixiu-statistics-web|kuaixiu-statistics-service|\
	kuaixiu-sys-web|kuaixiu-sys-service|\
	kuaixiu-finance-web|kuaixiu-finance-service|\
	kuaixiu-store-web|kuaixiu-store-service)
		project_dir_name=$(echo $project_name | grep -Eoi 'kuaixiu-[a-z]{3,10}')
		project_type=$(echo $project_name | grep -Eoi 'web|service')
		service_name=$(echo $project_name | grep -Eoi 'kuaixiu-[a-z]{3,10}')
		project_file_name=${original_project_name}.war
		back_file_name=${project_name}.${deploy_data}.tar.gz
		back_file_dir=${remote_www_dir}/tomcat-web/${project_dir_name}
		back_file=${project_type}
		deploy_dir=${remote_www_dir}/tomcat-web/${project_dir_name}/${project_type}
		deploy_file_path=${remote_project_dir}/${project_file_name}
		edit_war
		send_file
		auto_back
		auto_deploy
	;;
	kuaixiu-pc|kuaixiu-gw)
		project_file_name=${original_project_name}.tar.gz
		back_file_name=${project_name}.${deploy_data}.tar.gz
		back_file_dir=${remote_www_dir}/nginx-web/
		back_file=${project_name}
		deploy_dir=${remote_www_dir}/nginx-web/${project_name}
		deploy_file_path=${remote_project_dir}/${project_file_name}
		send_file
		auto_back
		auto_deploy
	;;
		*)
		echo "[ERROR] 无效的工程名!!!"
		exit 1
	;;
esac

