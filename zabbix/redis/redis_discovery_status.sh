#!/bin/bash
#查找redis的基础目录，根据实际情况修改
find_base_dir=/opt
home_dir=`find ${find_base_dir} -name redis.conf 2>/dev/null |awk -F "/etc/redis.conf" '{print $1}'`
deploy_mumber=`find ${find_base_dir} -name redis.conf 2>/dev/null |awk -F "/etc/redis.conf" '{print $1}'|wc -l`

discovery_redis(){
	i=1
	echo -e '{\n'
	echo -e '\t"data":[\n'

	for j in $home_dir
	do
		base_dir=`echo "$j"|awk -F"/" '{print $(NF)}'`
		ip=`cat "$j/etc/redis.conf" | grep ^bind | grep -oE [0-9.]+ | head -1`
		port=`cat "$j/etc/redis.conf" | grep ^port | grep -oE [0-9]+`
		passwd=`cat "$j/etc/redis.conf" | grep ^requirepass | awk '{print $2}'`
		if [[ "$i" < "${deploy_mumber}" ]];then
			echo -e '\t\t{\n'
			echo -e "\t\t\t\"{#BASE_DIR}\":\"${base_dir}\",\n"
			echo -e "\t\t\t\"{#IP}\":\"${ip}\",\n"
			echo -e "\t\t\t\"{#PORT}\":\"${port}\"\n"
			echo -e '\t\t},'
		else
			echo -e '\t\t{\n'
			echo -e "\t\t\t\"{#BASE_DIR}\":\"${base_dir}\",\n"
			echo -e "\t\t\t\"{#IP}\":\"${ip}\",\n"
			echo -e "\t\t\t\"{#PORT}\":\"${port}\"\n"
			echo -e '\t\t}'
		fi
		let "i=i+1"
	done

	echo -e '\t]'
	echo -e '}'
}

redis_status(){

	ip=`cat "${find_base_dir}/${base_dir}/etc/redis.conf" | grep ^bind | grep -oE [0-9.]+ | head -1`
	port=`cat "${find_base_dir}/${base_dir}/etc/redis.conf" | grep ^port | grep -oE [0-9]+`
	passwd=`cat "${find_base_dir}/${base_dir}/etc/redis.conf" | grep ^requirepass | awk '{print $2}'`
	if [[ -z ${passwd} ]];then
		if [[ ${arg} = 'ping' ]];then
			${find_base_dir}/${base_dir}/bin/redis-cli -h ${ip} -p ${port} ping 2>/dev/null | grep -q PONG && echo 1 || echo 0
		else
			${find_base_dir}/${base_dir}/bin/redis-cli -h ${ip} -p ${port} info 2>/dev/null| grep ^${arg}: | awk -F ':' '{print $2}'
		fi
	else
		if [[ ${arg} = 'ping' ]];then
			${find_base_dir}/${base_dir}/bin/redis-cli -h ${ip} -p ${port} -a ${passwd} ping 2>/dev/null | grep -q PONG && echo 1 || echo 0
		else
			${find_base_dir}/${base_dir}/bin/redis-cli -h ${ip} -p ${port} -a ${passwd} info 2>/dev/null | grep ^${arg}: | awk -F ':' '{print $2}'
		fi
	fi
}

if [[ ${1} = 'discovery' ]] ;then
	discovery_redis
else
	base_dir=${1}
	arg=${2}
	redis_status
fi
