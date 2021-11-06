#!/bin/bash
. /etc/profile
#PATH=/opt/java/bin:$PATH
#程序名称
pro_name=$1
#进程ID
pid_number=$2
#监控指标
item=$3

jvm_status(){
	#获取JVM所有指标
	> /tmp/jvm-${pid_number}-gccapacity.txt
	> /tmp/jvm-${pid_number}-gc.txt
	jstat -gccapacity ${pid_number} > /tmp/jvm-${pid_number}-gccapacity.txt 2>/dev/null && \
	jstat -gc ${pid_number} > /tmp/jvm-${pid_number}-gc.txt 2>/dev/null && \
	echo 1 || echo 0
}


case ${item} in
	all)
		jvm_status
	;;
	S0U|S1U|EU|OU|MU)
		awk 'NR==1{for(i=1;i<=NF;i++) if ($i ~ /'${item}'/){break}}NR==2{print $i*1000}' /tmp/jvm-${pid_number}-gc.txt
	;;
	YGC|FGC|GCT|FGCT)
		awk 'NR==1{for(i=1;i<=NF;i++) if ($i ~ /'${item}'/){break}}NR==2{print $i}' /tmp/jvm-${pid_number}-gc.txt
	;;
	Threads)
		grep 'Threads' /proc/${pid_number}/status | grep -oE '[0-9]{1,}'
	;;
	*)
		awk 'NR==1{for(i=1;i<=NF;i++) if ($i ~ /'${item}'/){break}}NR==2{print $i*1000}' /tmp/jvm-${pid_number}-gccapacity.txt
	;;
esac
