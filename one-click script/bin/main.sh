#!/bin/bash
###########################################################
#System Required: Centos 6+
#Description: Install the java tomcat mysql and tools
#Version: 2.0
#                                                        
#                            by---wang2017.7
###########################################################

. /etc/profile
. ./public.sh
. ./tools.sh
mysql_tool(){
output_option 'MySQL常用脚本' '添加MySQL备份脚本  找回MySQLroot密码 ' 'num'

case "$num" in
	1)backup_script_set.sh
	;;
	2)reset_mysql_passwd
	;;
esac
}

basic_environment(){

output_option '请选择要安装的环境' 'JDK PHP Ruby Nodejs' 'num'
case "$num" in
	1)install_java.sh
	;;
	2)install_php.sh
	;;
	3)install_ruby.sh
	;;
	4)install_node.sh
	;;
esac
}

web_services(){

output_option '请选择要安装的软件' 'Nginx Tomcat' 'num'
case "$num" in
	1)install_nginx.sh
	;;
	2)install_tomcat.sh
	;;
esac
}

database_services(){

output_option '请选择要安装的软件' 'MySQL mongodb Redis Memcached' 'num'
case "$num" in
	1)install_mysql.sh
	;;
	2)install_mongodb.sh
	;;
	3)install_redis.sh
	;;
	4)install_memcached.sh
	;;
esac
}

middleware_services(){

output_option '请选择要安装的软件' 'ActiveMQ RocketMQ Zookeeper Kafka' 'num'
case "$num" in
	1)install_activemq.sh
	;;
	2)install_rocketmq.sh
	;;
	3)install_zookeeper.sh
	;;
	4)install_kafka.sh
	;;
esac
}

storage_service(){

output_option '请选择要安装的软件' 'FTP SFTP 对象存储服务(OSS/minio) FastDFS NFS' 'num'
case "$num" in
	1)install_ftp.sh
	;;
	2)add_sysuser && add_sysuser_sftp
	;;
	3)install_minio.sh
	;;
	4)install_fastdfs.sh
	;;
	5)install_nfs.sh
	;;
esac
}

operation_platform(){
output_option '请选择要安装的平台' 'K8S系统 ELK日志平台 Zabbix监控 Rancher平台(k8s集群管理)' 'platform'
case "$platform" in
	1)install_k8s.sh
	;;
	2)elk_install_ctl
	;;
	3)install_zabbix.sh
	;;
esac

}

tools(){
output_option '请选择进行的操作' '优化系统配置 查看系统详情 升级内核版本 创建用户并将其加入visudo 安装WireGuard-VPN 多功能备份脚本 主机ssh互信' 'tool'
case "$tool" in
	1)system_optimize.sh
	;;
	2)sys_info_detail
	;;
	3)update_kernel
	;;
	4)add_sysuser && add_sysuser_sudo
	;;
	5)install_wireguard.sh
	;;
	6)backup_script_set.sh
	;;
	7)auto_ssh_keygen
	;;
esac
}

main(){

output_option '请选择需要安装的服务' '基础环境 WEB服务 数据库服务 中间件服务 存储服务 运维平台 其他工具' 'mian'

case "$mian" in
	1)basic_environment
	;;
	2)web_services
	;;
	3)database_services
	;;
	4)middleware_services
	;;
	5)storage_service
	;;
	6)operation_platform
	;;
	7)tools
	;;

esac
}

elk_install_ctl(){
	diy_echo "为了兼容性所有组件最好选择一样的版本" "${yellow}" "${info}"
	output_option "选择安装的组件" "elasticsearch logstash kibana filebeat" "elk_module"

	elk_module=${output_value[@]}
	if [[ ${output_value[@]} =~ 'elasticsearch' ]];then
		install_elasticsearch.sh
	elif [[ ${output_value[@]} =~ 'logstash' ]];then
		install_logstash.sh
	elif [[ ${output_value[@]} =~ 'kibana' ]];then
		install_kibana.sh
	elif [[ ${output_value[@]} =~ 'filebeat' ]];then
		install_filebeat.sh
	fi	
}

clear
[[ $EUID -ne 0 ]] && echo -e "${error} Need to use root account to run this script!" && exit 1
echo -e "+ + + + + + + + + + + + + + + + + + + + + + + + + +"
echo -e "+ System Required: Centos 6+                      +"
echo -e "+ Description: Multi-function one-click script    +"
echo -e	"+                                                 +"
echo -e "+                                   Version: 2.1  +"
echo -e "+                                 by---wang2017.7 +"
echo -e "+ + + + + + + + + + + + + + + + + + + + + + + + + +"
colour_keyword
sys_info
main

