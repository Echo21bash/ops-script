#!/bin/bash

. ./public.sh
bcache_set(){

	output_option '选择操作' '全新配置bcache缓存 清除bcache配置及设备 查看状态' 'ops'
	all_dev=`lsblk -d  | awk 'NR>1{print "/dev/"$1}'`
	if [[ ${ops} = '1' ]];then
		output_option '选择缓存设备' "${all_dev}" 'dev_c'
		dev_c=(${output_value})
		other_dev=`lsblk -d  | awk 'NR>1{print "/dev/"$1}' | grep -v "$dev_c"`
		output_option '选择后端设备可多选' "${other_dev}" 'dev_b'
		dev_b=(${output_value[@]})
		creat_bcache_dev
	fi
	if [[ ${ops} = '2' ]];then
		del_bcache_dev
	fi
}

creat_bcache_dev(){

	make-bcache -C $dev_c -B ${dev_b[@]} --wipe-bcache

}

del_bcache_dev(){

	dev_c_uuid=`ll /sys/fs/bcache/ | grep -oE "[a-z0-9\-]{36,}"`
	all_bcache_dev=`ls /sys/block | grep -E "bcache[0-9]{1,}"`
	#解绑缓存关系
	for j in ${dev_c_uuid[@]}
	do
		for a in ${all_dev[@]}
		do
			if [[ -n `bcache-super-show $a | grep backing` ]];then
				uuid=`bcache-super-show $a | grep cset.uuid | awk '{printf $2}'`
				if [[ $j = $uuid ]];then
					for x in ${all_bcache_dev[@]}
					do
						backing_=`ll /sys/block/$x/bcache | grep -oE "sd[a-z]{1}"`
						if [[ /dev/${backing_} = ${a} ]];then
							echo "$j">/sys/block/$x/bcache/detach && diy_echo "解绑$x"
						fi
					done
				fi
			fi
		done
	done
	#停止后端设备
	all_bcache_dev=`ls /sys/block | grep -E "bcache[0-9]{1,}"`
	for x in ${all_bcache_dev[@]}
	do
		backing_=`ll /sys/block/$x/bcache | grep -oE "sd[a-z]{1}"`
		echo "1">/sys/block/$x/bcache/stop && diy_echo "停止$x"
	done
	#停止缓存设备
	dev_c_uuid=`ll /sys/fs/bcache/ | grep -oE "[a-z0-9\-]{36,}"`
	for j in ${dev_c_uuid[@]}
	do
		echo "1" >/sys/fs/bcache/$j/unregister && diy_echo "停止$j"
	done
}

check_bcache_mod(){
	if [[ `lsmod | grep ^bcache` ]];then
		return 0
	else
		exit 1
	fi
}



colour_keyword
sys_info
check_bcache_mod
bcache_set


