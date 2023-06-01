#!/bin/bash
#通过读取文件获取，降低k8s压力，防止zabbix执行超时
#其他的监控项依赖于pod.status[all]监控项


metric=$1
pod_name=$2

get_pod_all_status(){

        kubectl get deployments.apps | awk '{print$1}' | sed '1d' > /tmp/apps.txt
        kubectl top pod | sed '1d' > /tmp/top_status.txt
        kubectl get pod | sed '1d' > /tmp/pod_status.txt
        echo $?
}

get_pod_cpu_status(){

        cat /tmp/top_status.txt | grep ${pod_name} | awk '{print$2}' | grep -oE "[0-9]{1,}"

}

get_pod_mem_status(){

        cat /tmp/top_status.txt | grep ${pod_name} | awk '{print$3}' | grep -oE "[0-9]{1,}"
}

get_pod_status(){

        cat /tmp/pod_status.txt | grep ${pod_name} | awk '{print$3}'

}

get_pod_no_running(){

        cat /tmp/pod_status.txt | awk '{print$3}' | grep -v "Running" | wc -l
}

get_pod_running(){

        cat /tmp/pod_status.txt | awk '{print$3}' | grep "Running" | wc -l
}

case $metric in
        cpu)
                get_pod_cpu_status
        ;;
        mem)
                get_pod_mem_status
        ;;
        stat)
                get_pod_status
        ;;
        no_running)
                get_pod_no_running
        ;;
        running)
                get_pod_running
        ;;
        all)
                get_pod_all_status
        ;;
esac
