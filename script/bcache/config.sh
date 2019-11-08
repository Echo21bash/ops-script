#!/bin/bash

. ./public.sh
bcache_set(){

	output_option '选择操作' '全新配置bcache缓存 清除bcache配置及设备' 'ops'
	all_dev=(`lsblk -d  | awk 'NR>1{print "/dev/"$1}' | grep -v /dev/sda`)
	if [[ ${ops} = '1' ]];then
		output_option '选择缓存模式' "writethrough writeback writearound" 'cache_mode'
		cache_mode=${output_value}
		output_option '选择缓存设备' "${all_dev[@]}" 'dev_c'
		dev_c=${output_value}
		other_dev=(`lsblk -d  | awk 'NR>1{print "/dev/"$1}' | grep -v /dev/sda | grep -v "$dev_c"`)
		output_option '选择后端设备可多选' "${other_dev[@]}" 'dev_b'
		dev_b=(${output_value[@]})
		creat_bcache_dev
		conf_bcache_dev
	
	 elif [[ ${ops} = '2' ]];then
		diy_echo '清除配置前请先卸载设备' "${yellow}" "${info}"
		input_option "是否清除配置?" "n"
		clear=${input_value}
		if [[ ${clear} = "y" || ${clear} = "Y" ]]; then
			del_bcache_dev
		else
			diy_echo "取消操作.." "${info}"
		fi
	fi
}

creat_bcache_dev(){

	make-bcache -C ${dev_c} -B ${dev_b[@]} --wipe-bcache --block 4k --bucket 2M
	if [ $? = 0 ];then
		#配置并优化
		sleep 5
		bcache_cacahe_dev_uuid=(`ll /sys/fs/bcache/ | grep -oE "[a-z0-9\-]{36,}"`)
		bcache_name=(`ls /sys/block | grep -E "bcache[0-9]{1,}"`)
		if [[ -n ${bcache_cacahe_dev_uuid[@]} && -n ${bcache_name[@]} ]];then
 			diy_echo '创建bcache设备成功，然后进行格式化bcache及挂载' "${green}" "${info}"
		fi

	else
		diy_echo '创建bcache设备失败' "${red}" "${error}"
		exit 1
	fi
}

conf_bcache_dev(){

		mkdir -p /etc/tmpfiles.d
		for name in ${bcache_name[@]}
		do
			echo "w /sys/block/$name/bcache/cache_mode  - - - - ${cache_mode}" >> /etc/tmpfiles.d/bcache.conf
			echo "w /sys/block/$name/bcache/sequential_cutoff  - - - - 104857600" >> /etc/tmpfiles.d/bcache.conf
			echo "w /sys/block/$name/bcache/readahead  - - - - 104857600" >> /etc/tmpfiles.d/bcache.conf
		done

		for uuid in ${bcache_cacahe_dev_uuid[@]}
		do
			echo "w /sys/fs/bcache/$uuid/congested_read_threshold_us  - - - - 0" >> /etc/tmpfiles.d/bcache.conf
			echo "w /sys/fs/bcache/$uuid/congested_write_threshold_us  - - - - 0" >> /etc/tmpfiles.d/bcache.conf
		done

}

del_bcache_dev(){
	#所有缓存设备名及UUID
	bcache_cacahe_dev_uuid=(`ll /sys/fs/bcache/ | grep -oE "[a-z0-9\-]{36,}"`)
	i=0
	for j in ${bcache_cacahe_dev_uuid[@]}
	do	
		bcache_cacahe_dev[$i]=`ls -l /sys/fs/bcache/$j/cache0 | grep -Eo "block/sd*/bcache" | awk -F / '{print $2}'`
		((i++))
	done
	#所有bcache名称、后端设备名及UUID
	bcache_name=(`ls /sys/block | grep -E "bcache[0-9]{1,}"`)
	i=0
	for x in ${bcache_name[@]}
	do
		bcache_backing_dev[$i]=`ll /sys/block/$x/bcache | grep -oE "sd[a-z]{1}"`
		bcache_backing_dev_uuid[$i]=`bcache-super-show $bcache_backing_dev[$i] | grep cset.uuid | awk '{printf $2}'`
		((i++))
	done
	
	#解绑缓存关系
	i=0
	for j in ${bcache_cacahe_dev_uuid[@]}
	do
		for a in ${bcache_backing_dev_uuid[@]}
		do
			if [[ $j = $a ]];then
				echo "$j">/sys/block/$bcache_name[$i]/bcache/detach && diy_echo "解绑${bcache_name[$i]}完成"
			fi
		done
		((i++))
	done
	#停止后端设备
	for x in ${bcache_name[@]}
	do
		echo "1">/sys/block/$x/bcache/stop && diy_echo "停止$x的后端设备完成"
		umount /dev/$x && diy_echo "卸载$x设备完成"
	done
	#停止缓存设备
	i=0
	for j in ${bcache_cacahe_dev_uuid[@]}
	do
		echo "1" >/sys/fs/bcache/$j/unregister && diy_echo "停止缓存设备${bcache_cacahe_dev[$i]}完成"
	done
	if [ -f /etc/tmpfiles.d/bcache.conf ];then
		rm -rf /etc/tmpfiles.d/bcache.conf.back
		mv	/etc/tmpfiles.d/bcache.conf /etc/tmpfiles.d/bcache.conf.back
	fi
}

check_bcache_mod(){
	if [[ `lsmod | grep ^bcache` ]];then
		return 0
	else
		exit 1
	fi
}

colour_keyword
check_bcache_mod
bcache_set
