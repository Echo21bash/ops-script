#!/bin/bash

app_names=`kubectl get deployments | sed '1d' | awk '{print$1}'`
app_names="${app_names} `kubectl get daemonsets | sed '1d' | awk '{print$1}'`"
app_names=(${app_names})
pod_mumber=`kubectl get pod | sed '1d' | awk '{print$1}' | wc -l`

i=1
echo -e '{\n'
echo -e '\t"data":[\n'


for now_app in ${app_names[@]}
do
	pod_name=`kubectl get pod | sed '1d' | grep ${now_app} | awk '{print$1}'`
	pod_name=(${pod_name})
	for now_pod in ${pod_name[@]}
	do
		if [[ "$i" < "${pod_mumber}" ]];then
			echo -e '\t\t{\n'
			echo -e "\t\t\t\"{#APP_NAME}\":\"${now_app}\"\n"
			echo -e "\t\t\t\"{#POD_NAME}\":\"${now_pod}\"\n"
			echo -e '\t\t},'
		else
			echo -e '\t\t{\n'
			echo -e "\t\t\t\"{#APP_NAME}\":\"${now_app}\"\n"
			echo -e "\t\t\t\"{#POD_NAME}\":\"${now_pod}\"\n"
			echo -e '\t\t}'
		fi
		let "i=i+1"
	
	done

done

echo -e '\t]'
echo -e '}'
