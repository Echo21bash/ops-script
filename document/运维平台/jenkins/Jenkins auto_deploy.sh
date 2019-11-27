#!/bin/bash
###########################################################
#System Required: Centos 6+
#Description: jenkins auto
#Version: 2.0
#                                                        
#                            by---wang2019.1
###########################################################

#需要安装sshpass命令

#jenkins ssh传到服务器的项目包路径
over_ssh_dir='/apps/data/sftp/www'
#jenkins工作目录
jenkins_work_dir='/root/.jenkins/jobs'
#远程服务器项目包存放路径
remote_over_ssh_dir='/dachang/data/www'
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
#统一转换为小写

#原本打包后的包名
war_name="$1".war
#原本工程名
original_project_name="$1"
#将工程名统一转换为小写
lower_case_project_name=$(echo $1 | tr [A-Z] [a-z])
#工程名
project_name=$(echo $lower_case_project_name | grep -Eoi 'kuaixiu-[a-z]{3,9}')
project_dir_name=$(echo $lower_case_project_name | grep -Eoi 'kuaixiu-[a-z]{3,9}')
project_type=$(echo $lower_case_project_name | grep -Eoi 'web|service')
service_name=$(echo $lower_case_project_name | grep -Eoi 'kuaixiu-[a-z]{3,9}')
#服务器ip
server=('172.26.55.186' '172.26.218.50' '172.26.218.51')
#服务器用户
server_user=('root' 'root' 'root')
#服务器密码
server_pass=('kxjsb@123' 'kxjsb@123' 'kxjsb@123')
#服务器ssh端口
server_port=('52233' '52233' '52233')
#远程服务器项目路径
remote_www_dir='/dachang/www'
#日期
deploy_data=$(date +"%Y-%m-%d")

#$1服务器数组序号、$2本机路径、$3发送文件名、$4远程路径
send_file(){

	sshpass -p ${server_pass[$1]} scp -P ${server_port[$1]} -r $2/$3 ${server_user[$1]}@${server[$1]}:$4/$3
	if [[ $? = '0' ]];then
		echo "发送$3完成"
	else
		echo "发送$3失败"
		exit
	fi
}
#$1服务器数组序号、$2备份路径、$3备份文件名、$4需要备份路径、$5需要备份文件
auto_back(){

	sshpass -p ${server_pass[$1]} ssh -p ${server_port[$1]} ${server_user[$1]}@${server[$1]}<<EOF
	#备份
	if [[ ! -f $2/$3 ]];then
		cd $4
		tar zcf $3 $5
		mv $3 $2
		if [[ $? = '0' ]];then
			echo "${3}备份完成,路径为$2/$3"
		fi
	else
		echo "${3}已经存在备份,路径为$2/$3"
	fi
	exit
EOF
}
#$1服务器数组序号、$2www路径、$3部署文件包括路径、$4服务名
auto_deploy(){

	sshpass -p ${server_pass[$1]} ssh -p ${server_port[$1]} ${server_user[$1]}@${server[$1]}<<EOF
	#停止并清空
	systemctl stop ${4}
	sleep 5
	rm -rf ${2}/*
	unzip -o ${3} -d ${2} || tar -zxvf ${3} -C ${2}
	chmod -R 755 ${2}
	#启动
	systemctl start ${4}
EOF
	if [[ $? = '0' ]];then
		echo "自动部署${3}完成"
	else
		echo "自动部署${3}失败"
		exit
	fi
}

kuaiXiuPc_conf(){
	. /etc/profile.d/node.sh
	project_dir="${jenkins_work_dir}/web_ui_prod/workspace"
	cd ${project_dir}

	sed -i "s#index: path.resolve(__dirname, '../../app/dist/index.html'),#index: path.resolve(__dirname, '../dist/index.html'),#" ${project_dir}/config/index.js
	sed -i "s#assetsRoot: path.resolve(__dirname, '../../app/dist'),#assetsRoot: path.resolve(__dirname, '../dist'),#" ${project_dir}/config/index.js
	[[ ! -d ${project_dir}/node_modules ]] && npm i --unsafe-perm
	npm run build
	if [[ $? = '0' ]];then
		echo '编译完成'
		cd ${project_dir}/dist
		rm -rf ./${project_name}.tar.gz
		tar zcf ${project_name}.tar.gz ./*
	else
		echo '编译失败'
		exit
	fi
}

kuaixiugw_conf(){
	. /etc/profile.d/node.sh
	project_dir="${jenkins_work_dir}/web_ui_prod/workspace"
	cd ${project_dir}
	npm i
	rm -rf ./${project_name}.tar.gz
	tar zcf ${project_name}.tar.gz ./*
}
#区分项目
if [[ ${project_name} = 'kuaixiu-bus' || ${project_name} = 'kuaixiu-stock' || ${project_name} = 'kuaixiu-crm' ]];then
	send_file 0 ${over_ssh_dir} ${war_name} ${remote_over_ssh_dir}
	auto_back 0 ${remote_over_ssh_dir} ${project_name}-${project_type}.${deploy_data}.tar.gz ${remote_www_dir}/tomcat-web/${project_dir_name} ${project_type}
	auto_deploy 0 ${remote_www_dir}/tomcat-web/${project_dir_name}/${project_type} ${remote_over_ssh_dir}/${war_name} ${service_name}
fi

if [[ ${project_name} = 'kuaixiu-sys' || ${project_name} = 'kuaixiu-finance' || ${project_name} = 'kuaixiu-store' ]];then
	send_file 1 ${over_ssh_dir} ${war_name} ${remote_over_ssh_dir}
	auto_back 1 ${remote_over_ssh_dir} ${project_name}-${project_type}.${deploy_data}.tar.gz ${remote_www_dir}/tomcat-web/${project_dir_name} ${project_type}
	auto_deploy 1 ${remote_www_dir}/tomcat-web/${project_dir_name}/${project_type} ${remote_over_ssh_dir}/${war_name} ${service_name}
fi

if [[ ${project_name} = 'kuaixiupc' ]];then
	kuaiXiuPc_conf
	send_file 2 ${project_dir}/dist ${project_name}.tar.gz ${remote_over_ssh_dir}
	auto_back 2 ${remote_over_ssh_dir} ${project_name}.${deploy_data}.tar.gz ${remote_www_dir}/nginx-web kuaixiu-web
	auto_deploy 2 ${remote_www_dir}/nginx-web/kuaixiu-web ${remote_over_ssh_dir}/${project_name}.tar.gz
fi

if [[ ${project_name} = 'kuaixiu-gw' ]];then
	kuaixiugw_conf
	send_file 2 ${project_dir} ${project_name}.tar.gz ${remote_over_ssh_dir}
	auto_back 2 ${remote_over_ssh_dir} ${project_name}.${deploy_data}.tar.gz ${remote_www_dir}/nginx-web kuaixiugw-web
	auto_deploy 2 ${remote_www_dir}/nginx-web/kuaixiugw-web ${remote_over_ssh_dir}/${project_name}.tar.gz
fi
