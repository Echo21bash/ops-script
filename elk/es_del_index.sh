#!/bin/bash

###################################
#删除ES集群的索引
#适用于索引按天创建并且日期格式为2020.01.01
###################################
log_file='del_index.log'
index_file='index.txt'
es_ip='172.26.32.173:9200'
#es_user='elastic'
#es_passwd='123456'
#索引保留天数
day=30

public(){
	if [[ -z ${es_user} ]];then
		exec="curl -k -s"
	else
		exec="curl -k -s -u ${es_user}:${es_passwd}"
	fi

}

get_index(){
	if [[ -z ${es_user} ]];then
		${exec} -XGET http://${es_ip}/_cat/indices | awk '{print $3}' >${index_file}
	else
		${exec} -XGET http://${es_ip}/_cat/indices | awk '{print $3}' >${index_file}
	fi

}

delete_index(){
	comp_date=`date -d "${day} day ago" +"%Y.%m.%d"`
	cat index.txt | grep -oE [0-9]{4}\.[0-9]{2}\.[0-9]{2} | sort -u | while read data
	do
		if [[ ${data} < ${comp_date} ]];then
			cat index.txt | grep ${data} | while read LINE
			do
				res=`${exec} -IL -XDELETE http://${es_ip}/${LINE} | grep 'HTTP/1.1 200'`
				if [[ -n ${res} ]];then
					echo "${LINE}删除成功"
				else
					echo "${LINE}删除失败"
				fi
			done
		fi
	done
}

main(){
	public >>${log_file}
	get_index >>${log_file}
	delete_index >>${log_file}
}

main