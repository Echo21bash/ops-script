#脚本用于检测公网ip
#最新IP地址/tmp/intnet_ip.txt
#上次IP地址/tmp/intnet_ip_old.txt
#网络状态 1为正常、0为不正常 /tmp/intnet_status.txt
#IP发生改变 1为发生改变、0为未发生改变 /tmp/intnet_change.txt

get_public_ip(){

	for ((i=1;i<4;i++))
	do
		
		new_ip=`curl -s --connect-timeout 2 https://pv.sohu.com/cityjson 2>/dev/null | awk -F '"' '{print $4}' | grep -oE "[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}"`
		if [[ -n ${new_ip} ]];then
			echo ${new_ip} >/tmp/intnet_ip.txt
			echo 1 >/tmp/intnet_status.txt
			break
		else
			new_ip=`curl -s --connect-timeout 2 https://ipv4.icanhazip.com 2>/dev/null | grep -oE "[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}"`
			if [[ -n ${new_ip} ]];then
				echo ${new_ip} >/tmp/intnet_ip.txt
				echo 1 >/tmp/intnet_status.txt
				break
			fi
		fi
	done
	
	if [[ x${new_ip} = x ]];then
		echo 0 >/tmp/intnet_status.txt
		echo ${new_ip} >/tmp/intnet_ip.txt
	fi

}

internet_ip(){

	get_public_ip
	cat /tmp/intnet_ip.txt

}

internet_status(){

	if [[ -f /tmp/intnet_status.txt ]];then
		cat /tmp/intnet_status.txt

	else
		get_public_ip
		cat /tmp/intnet_status.txt
	fi
}

internet_ip_change(){

	if [[ -f /tmp/intnet_ip.txt ]];then
		new_ip=`cat /tmp/intnet_ip.txt`
	else
		get_public_ip
		new_ip=`cat /tmp/intnet_ip.txt`
	fi
	
	if [[ -f /tmp/intnet_ip_old.txt ]];then
		old_ip=`cat /tmp/intnet_ip_old.txt`
	else
		cp /tmp/intnet_ip.txt /tmp/intnet_ip_old.txt
		old_ip=`cat /tmp/intnet_ip_old.txt`
	fi
	
	if [[ ${old_ip} = ${new_ip} ]];then
		echo 0 > /tmp/intnet_change.txt
	else
		##发生变化后更新旧的ip为当前ip
		\cp /tmp/intnet_ip.txt /tmp/intnet_ip_old.txt
		echo 1 > /tmp/intnet_change.txt
	fi
	
	cat /tmp/intnet_change.txt
}

case $1 in

	internet_ip)
		internet_ip
	;;
	internet_status)
		internet_status
	;;

	internet_ip_change)
		internet_ip_change
	;;
esac

