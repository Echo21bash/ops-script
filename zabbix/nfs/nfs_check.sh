#!/bin/bash


check_share_dir(){
	# Init NFS share not available (epmty by default)
	result=""

	# get nfs information using showmount without error messages
	nfsdata=$(showmount -e 127.0.0.1 2> /dev/null | awk '{print$1}' | grep "^/")
	echo $nfsdata
}


check_nfs_status(){
	
	nfs_status=`rpcinfo 127.0.0.1 -t nfs | grep -o 'ready'`
	if [[ -n ${nfs_status} ]];then
		echo 0
		exit 0
	else
		echo 1
		exit 1
	fi
}

check_nfs_pro_num(){
	
	nfs_status=`ps aux | grep -v grep | grep nfsd | wc -l`
	if [[ ${nfs_status} > '0' ]];then
		echo ${nfs_status}
		exit 0
	else
		exit 1
	fi
}

case "$1" in
	status)
		check_nfs_status
	;;
	pro_num)
		check_nfs_pro_num
	;;
	share_dir)
		check_share_dir
	;;
	*)
		echo $"Usage $0 {status|pro_num|share_dir}"
		exit
esac
