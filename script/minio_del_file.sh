#!/bin/bash
###################################
#删除minio对象脚本
#需要安装mc客户端并正确配置.mc/config.json
###################################

#minio服务别名
server_name=('local')
#申明关联数组
declare -A bucket_name
#存储桶名称
bucket_name=([local]='device-logs')
#保留天数
day='30'
for now_server_name in ${server_name[@]}
do
	bucket_list=(${bucket_name[$now_server_name]})
	for now_bucket in ${bucket_list[@]}
	do
		mc rm  --force --recursive --older-than=${day}d ${now_server_name}/${now_bucket}
	done

done
