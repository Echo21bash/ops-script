#!/bin/bas h
script_abs=$(readlink -f "$0")
script_dir=$(dirname $script_abs)
cd ${script_dir}
source ../conf/monitor.conf
monitor_fun(){
	alert_status="0"
	while true
	do
		for time in 0 1 2
		do
			sleep ${interval_time}
			status[${time}]=`${script_dir}/get-status.sh ${app_name} ${url}`
		done
		if [[ ${alert_status} = "0" && ${status[@]} = "0 0 0" ]];then
			alert_status="1"
			alarm_problem_fun
		elif [[ ${alert_status} = "1" && ${status[@]} = "1 1 1" ]];then
			alert_status="0"
			alarm_ok_fun
		fi
	done
}

alarm_problem_fun(){

	if [[ ${alarm_channel[@]} =~ "wechat" ]];then
		${script_dir}/wechat-robot.sh --token="${wechat_token}" -a -m "告警时间:`date "+%Y-%m-%d %H:%M:%S"`;\n告警项目:${app_name};\n告警详情:${url};\n当前状态:故障;"
	fi
	if [[ ${alarm_channel[@]} =~ "dingtalk" ]];then
		${script_dir}/dingtalk-robot.sh --token="${dingtalk_token}" -a -m "告警时间:`date "+%Y-%m-%d %H:%M:%S"`;\n告警项目:${app_name};\n告警详情:${url};\n当前状态:故障;"
	fi
}

alarm_ok_fun(){

	if [[ ${alarm_channel[@]} =~ "wechat" ]];then
		${script_dir}/wechat-robot.sh --token="${wechat_token}" -a -m "恢复时间:`date "+%Y-%m-%d %H:%M:%S"`;\n恢复项目:${app_name};\n恢复详情:${url};\n当前状态:恢复;"
	fi
	if [[ ${alarm_channel[@]} =~ "dingtalk" ]];then
		${script_dir}/dingtalk-robot.sh --token="${dingtalk_token}" -a -m "恢复时间:`date "+%Y-%m-%d %H:%M:%S"`;\n恢复项目:${app_name};\n恢复详情:${url};\n当前状态:恢复;"
	fi
}

run_ctl(){
	for i in ${!monitor_list[@]}
	do
		
		app_name="${i}"
		url="${monitor_list[${i}]}"
		monitor_fun &
	done

}


run_ctl
