#!/bin/bash
#use zabbix to monitor mysql
#author: hebaodan

mysql_home='/apps/base-env/mysql'
user='root'
password='dachang@2019'
mysql_sock='/apps/data/mysql_data/mysql-3307/mysql.sock'
#指标项
arg=$1
#参数类型
type=$2

status_mysql(){
#cmd='${mysql_home}/bin/mysql --login-path=root -e "$1"'
cmd="${mysql_home}/bin/mysql -u${user} -S${mysql_sock} -p${password} -e '$1' 2>/dev/null"
cmd2="${mysql_home}/bin/mysqladmin -u${user} -S${mysql_sock} -p${password} '$1' 2>/dev/null"

if [[ ${arg} = 'ping' ]];then
	result=$(eval $cmd2 | grep -c alive)
	echo ${result}
elif [[ ${arg} = 'slave' ]];then
	result=$(eval $cmd | grep "\b${arg}\b"|awk '{print $2}' | egrep '(Slave_IO_Running|Slave_SQL_Running):' | awk -F: '{print $2}' | tr '\n' ',')
	if [[ "$result" = " Yes, Yes," ]]; then
        echo 1
    else
        echo 0
    fi
else
	result=$(eval $cmd | grep "\b${arg}\b"|awk '{print $2}')
	echo ${result}
fi
}

if [[ ${type} = 'config' ]] ;then
	status_mysql "show variables"
elif [[ ${type} = 'status' ]];then
	case ${arg} in
	slave)
		status_mysql "show slave status\G"
	;;
	ping)
		status_mysql "ping"
	;;
	*)
		status_mysql "show global status"
	;;
	esac
fi
