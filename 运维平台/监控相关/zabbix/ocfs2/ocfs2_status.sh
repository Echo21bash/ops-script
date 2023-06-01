#!/bin/bash
##################################################
# Description：zabbix 监控 ocfs2 文件系统
##################################################


case "$1" in
	cluster_status)
		status=`o2cb.init status | grep cluster | grep -o Online`
		if [[ $status = 'Online' ]];then
			echo 0
		else
			echo 1
		fi
		;;
	heartbeat_status)
		status=`o2cb.init status | grep heartbeat | grep -o Active`
		if [[ $status = 'Active' ]];then
			echo 0
		else
			echo 1
		fi
		;;
	*)
		echo $"Usage $0 {cluster_status|heartbeat_status}"
		exit		
esac
