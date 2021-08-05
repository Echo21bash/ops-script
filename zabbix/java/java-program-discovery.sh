#!/bin/bash
	program_name=(`jps | grep -iv jps | awk '{print$2}'`)
	pid_number=(`jps | grep -iv jps | awk '{print$1}'`)
	jmx_port=`ps -aux | grep -Eo 'jmxremote.port=[0-9]{1,}' | grep -v grep 2>/dev/null | grep -E '[0-9]{1,}'`
	program_number=${#program_name[@]}
	
discovery_java_program(){

	echo -e '{\n'
	echo -e '\t"data":[\n'

	for ((i=0;i<${program_number};i++))
	do
		if [[ ${i} = `expr ${program_number} - 1` ]];then
			echo -e '\t\t{\n'
			echo -e "\t\t\t\"{#PROGRAM_NAME}\":\"${program_name[$i]}\",\n"
			echo -e "\t\t\t\"{#PID_NUMBER}\":\"${pid_number[$i]}\"\n"
			echo -e '\t\t}'
		else
			echo -e '\t\t{\n'
			echo -e "\t\t\t\"{#PROGRAM_NAME}\":\"${program_name[$i]}\",\n"
			echo -e "\t\t\t\"{#PID_NUMBER}\":\"${pid_number[$i]}\"\n"
			echo -e '\t\t},'
		fi
	done

	echo -e '\t]'
	echo -e '}'
}

discovery_java_program
