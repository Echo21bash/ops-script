#!/bin/bash

item=$1
port=$2

zk_all_status(){
	echo mntr | nc localhost ${port} 2>/dev/null >/tmp/zookeeper_status.txt
	if [[ $? = '0' ]];then
		echo 1
	else
		echo 0
	fi
}

zk_ruok_status(){
	echo ruok | nc localhost ${port} 2>/dev/null | grep -q imok
	if [[ $? = '0' ]];then
		echo 1
	else
		echo 0
	fi
}

case ${item} in
	mntr)
		zk_all_status
	;;
	ruok)
		zk_ruok_status
	;;
	*)
		res=`cat /tmp/zookeeper_status.txt | grep ${item} | awk '{print$2}'`
		if [[ -n ${res} ]];then
			echo ${res}
		else
			echo 0
		fi
	;;
esac
