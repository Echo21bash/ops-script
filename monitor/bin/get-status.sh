#!/bin/bash
#应用名称
app_name=$1
#监测地址
#http类型url=http://www.baidu.com
#tcp类型url=tcp:www.baidu.com:80
url=$2

check(){
	check_type=`echo ${url} | awk -F ':' '{print$1}'`
	if [[ ${check_type} = 'tcp' ]];then
	tcp_ip=`echo ${url} | awk -F ':' '{print$2}'`
		tcp_port=`echo ${url} | awk -F ':' '{print$3}'`
		tcp_status=`timeout 3 telnet ${tcp_ip} ${tcp_port} 2>/dev/null | grep -o Connected | wc -l`
		if [[ ${tcp_status}  = '1' ]];then
			echo "1"
		else
			echo "0"
		fi
	fi			

	if [[ ${check_type} = 'http' ]];then
		http_code=`curl -sI ${url} 2>/dev/null | grep '^HTTP' | awk '{print$2}'`
		if [[ -n ${http_code} && ${http_code} = "200" ]];then
			echo "1"
		else
			echo "0" 
		fi
	fi

}

check

