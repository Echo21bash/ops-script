#!/bin/bash

###################################
#删除早于十天的ES集群的索引
###################################
es_ip='172.26.32.173:9200'
day=10
while true
do
	((day++))
	comp_date=`date -d "${day} day ago" +"%Y.%m.%d"`
	if [[ ! -z `curl -XGET http://${es_ip}/_cat/indices | awk '{print $3}' | grep "${comp_date}"` ]];then
		curl -XGET http://${es_ip}/_cat/indices | awk '{print $3}' | grep "${comp_date}" | while read LINE
		do
			curl -XDELETE http://${es_ip}/${LINE}
			if [[ $? = '0' ]];then
			echo "${LINE}删除成功"
			fi
		done
	else
		break
	fi
done

