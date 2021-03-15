#!/bin/bash
# this kubernetes pod status
# pod restart status
metric=$1
pod_name=$2

kubectl get deployments.apps | awk '{print$1}' | sed '1d' > /tmp/apps.txt
kubectl top pod | sed '1d' > /tmp/top_status.txt
kubectl get pod | sed '1d' > /tmp/pod_status.txt


get_pod_cpu_status(){

	cat /tmp/top_status.txt | grep ${pod_name} | awk '{print$2}' | grep -oE "[0-9]{1,}"

}

get_pod_mem_status(){

	cat /tmp/top_status.txt | grep ${pod_name} | awk '{print$3}' | grep -oE "[0-9]{1,}"
}

get_pod_status(){

	cat /tmp/pod_status.txt | grep ${pod_name} | awk '{print$3}'

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

esac