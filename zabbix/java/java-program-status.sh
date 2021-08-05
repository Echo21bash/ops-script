#!/bin/bash
#程序名称
pro_name=$1
#进程ID
pid_number=$2
#监控指标
item=$3

jvm_status(){
	jstat -gccapacity ${pid_number} > /tmp/jvm_${pid_number}.txt
}

item_status(){
	awk 'NR==1{for(i=1;i<=NF;i++) if ($i ~ /'${item}'/){break}}NR==2{print $i}' /tmp/jvm_${pid_number}.txt
}

case ${item} in
	all)
		jvm_status
	;;
	*)
		item_status
	;;
esac
