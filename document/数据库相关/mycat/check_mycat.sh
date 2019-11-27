#!/bin/bash
#check_mycat
mycat_user='root'
mycat_passwd='123456'
mycat_port='8066'
mycat_ip='127.0.0.1'

mysql -u${mycat_user} -h${mycat_ip} -P${mycat_port} -p${mycat_passwd}<<EOF
select user();
EOF
if [[ $? != '0' ]];then
	#/etc/init.d/keepalived stop
	#systemctl stop keepalived
fi
