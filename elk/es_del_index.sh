#!/bin/bash

###################################
#删除ES集群的索引
###################################
es_ip='172.26.32.173:9200'
#es_user='elastic'
#es_passwd='123456'
#索引保留天数
day=10

get_index(){
	if [[ -z ${es_user} ]];then
		curl -k -XGET http://${es_ip}/_cat/indices | awk '{print $3}' >index.txt
	else
		curl -k -u ${es_user}:${es_passwd} -XGET http://${es_ip}/_cat/indices | awk '{print $3}' >index.txt
	fi

}

delete_index(){
	while true
	do
		((day++))
		comp_date=`date -d "${day} day ago" +"%Y.%m.%d"`
		if [[ ! -z `cat index.txt | grep "${comp_date}" | grep "${comp_date}"` ]];then
			cat index.txt | grep "${comp_date}" | while read LINE
			do
				curl -k -XDELETE http://${es_ip}/${LINE}
				if [[ $? = '0' ]];then
					echo "${LINE}删除成功"
				fi
			done
		else
			break
		fi
		
	done

}

main(){
	get_index
	delete_index
}

main