#!/bin/bash

###################################
#删除ES集群的索引
###################################
log_file='/data/script/del_index.log'
index_file='/data/script/index.txt'
es_ip='172.16.2.135:9200'
es_user='elastic'
es_passwd='tyacc@123'
#索引冻结牺牲查询速度、缓解堆内存不足。需要大于6.6版本
#冻结多少天前的索引
freeze_day=60
#关闭多少天前的索引
#关闭索引释放内存，无法查询索引
close_day=90
#删除索引清理空间
delete_day=120

public(){
	if [[ -z ${es_user} ]];then
		exec="curl -k -s"
	else
		exec="curl -k -s -u ${es_user}:${es_passwd}"
	fi

}

get_index(){
	if [[ -z ${es_user} ]];then
		${exec} -XGET http://${es_ip}/_cat/indices | grep 'open' | awk '{print $3}' >${index_file}
	else
		${exec} -XGET http://${es_ip}/_cat/indices | grep 'open' | awk '{print $3}' >${index_file}
	fi

}

freeze_index(){
	echo *****************冻结索引*****************
	comp_date=`date -d "${freeze_day} day ago" +"%Y.%m.%d"`
	cat ${index_file} | grep -oE [0-9]{4}\.[0-9]{2}\.[0-9]{2} | sort -u | while read data
	do
		if [[ ${data} < ${comp_date} ]];then
			cat ${index_file} | grep ${data} | while read LINE
			do
				res=`${exec} -IL -XPOST http://${es_ip}/${LINE}/_freeze | grep 'HTTP/1.1 200'`
				if [[ -n ${res} ]];then
					echo "冻结索引${LINE}成功"
				else
					echo "冻结索引${LINE}删除"
				fi
			done
		fi
	done
}

close_index(){
	echo *****************关闭索引*****************
	comp_date=`date -d "${close_day} day ago" +"%Y.%m.%d"`
	cat ${index_file} | grep -oE [0-9]{4}\.[0-9]{2}\.[0-9]{2} | sort -u | while read data
	do
		if [[ ${data} < ${comp_date} ]];then
			cat ${index_file} | grep ${data} | while read LINE
			do
				res=`${exec} -IL -XPOST http://${es_ip}/${LINE}/_close | grep 'HTTP/1.1 200'`
				if [[ -n ${res} ]];then
					echo "关闭索引${LINE}成功"
				else
					echo "关闭索引${LINE}失败"
				fi
			done
		fi
	done
}

delete_index(){
	echo *****************删除索引*****************
	comp_date=`date -d "${delete_day} day ago" +"%Y.%m.%d"`
	cat ${index_file} | grep -oE [0-9]{4}\.[0-9]{2}\.[0-9]{2} | sort -u | while read data
	do
		if [[ ${data} < ${comp_date} ]];then
			cat ${index_file} | grep ${data} | while read LINE
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

other_opt(){

  ${exec} -XPUT -H 'Content-type':'application/json' "http://${es_ip}/_all/_settings?preserve_existing=true" -d '{ "index.max_docvalue_fields_search" : "500" }'

}

main(){
	other_opt
	public >>${log_file}
	get_index >>${log_file}
	freeze_index >>${log_file}
	close_index >>${log_file}
	delete_index >>${log_file}
}

main

