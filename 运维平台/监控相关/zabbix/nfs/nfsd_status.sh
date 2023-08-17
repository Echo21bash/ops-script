#!/bin/bash

common_items(){

	case "$1" in

		share)
			nfsdata=$(showmount -e 127.0.0.1 2> /dev/null | awk '{print$1}' | grep "^/")
			echo $nfsdata
		;;
		ready)
			nfs_status=$(rpcinfo 127.0.0.1 -t nfs 2> /dev/null | grep -o 'ready')
			if [[ -n ${nfs_status} ]];then
				echo 1
			else
				echo 0
			fi
		;;
		num)
			nfs_status=`ps aux 2> /dev/null | grep -v grep | grep nfsd | wc -l`
			if [[ ${nfs_status} > '0' ]];then
				echo ${nfs_status}
			else
				echo ${nfs_status}
			fi
		;;
	esac

}

net_items(){

	case "$1" in
		packets)
			cat /proc/net/rpc/nfsd |grep net |awk '{print $2}'
		;;
		udp.packets)
			cat /proc/net/rpc/nfsd |grep net |awk '{print $3}'
		;;
		tcp.packets)
			cat /proc/net/rpc/nfsd |grep net |awk '{print $4}'
		;;
		tcpconn)
			cat /proc/net/rpc/nfsd |grep net |awk '{print $5}'
		;;
	esac

}


io_items(){

	case "$1" in
		read)
			cat /proc/net/rpc/nfsd |grep io |awk '{print $2}'
		;;
		write)
			cat /proc/net/rpc/nfsd |grep io |awk '{print $3}'
		;;
	esac

}

th_items(){

	case "$1" in
		sum)
			cat /proc/net/rpc/nfsd |grep th |awk '{print $2}'
		;;
		packets.arrived)
			cat /proc/fs/nfsd/pool_stats 2> /dev/null |tail -n 1|awk '{print $2}'
		;;
		sockets.enqueued)
			cat /proc/fs/nfsd/pool_stats 2> /dev/null |tail -n 1|awk '{print $3}'
		;;
		woken)
			cat /proc/fs/nfsd/pool_stats 2> /dev/null |tail -n 1|awk '{print $4}'
		;;
		timedout)
			cat /proc/fs/nfsd/pool_stats 2> /dev/null |tail -n 1|awk '{print $5}'
		;;
	esac

}

rpc_items(){

	case "$1" in
		calls)
			cat /proc/net/rpc/nfsd |grep rpc |awk '{print $2}'
		;;
		badcalls)
			cat /proc/net/rpc/nfsd |grep rpc |awk '{print $3}'
		;;

	esac

}

rc_items(){

	case "$1" in
		hits)
			cat /proc/net/rpc/nfsd |grep rc |awk '{print $2}'
		;;
		misses)
			cat /proc/net/rpc/nfsd |grep rc |awk '{print $3}'
		;;
		nocache)
			cat /proc/net/rpc/nfsd |grep rc |awk '{print $4}'
		;;
	esac
}

case "$1" in

	common)
		common_items $2
	;;
	net)
		net_items $2
	;;
	io)
		io_items $2
	;;
	th)
		th_items $2
	;;
	rpc)
		rpc_items $2
	;;
	rc)
		rc_items $2
	;;
esac
