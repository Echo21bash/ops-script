#!/bin/bash
 
usage()
{
	cat <<-EOF
	Usage:${program} [OPTION]...
	-a,--all    通知所有人（可选）
	-m,--msg    消息内容（必须）
	-t,--mobile 通知指定人多人用','分割（可选）
	--token     企业微信机器人Token（必须）
	EOF
}

send_msg(){
	
	msg="`echo ${msg} | sed 's/"/\\\\"/g'`"
	if [[ x${isAtAll} = "x" && x${touser} = "x" ]];then
		curl https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=$token \
		-H 'Content-Type: application/json' \
		-d '{"msgtype":"text","text":{"content":"'"$msg"'"}}'
	fi
	
	if [[ ${isAtAll} = "true" && x${touser} = "x" ]];then
		curl https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=$token \
		-H 'Content-Type: application/json' \
		-d '{"msgtype":"text","text":{"content":"'"$msg"'","mentioned_mobile_list":["@all"]}}'
	fi
	
	if [[ ${isAtAll} = "true" && x${touser} != "x" ]];then
		curl https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=$token \
		-H 'Content-Type: application/json' \
		-d '{"msgtype":"text","text":{"content":"'"$msg"'","mentioned_mobile_list":['$touser',"@all"]}}'
	fi
	
	if [[ x${isAtAll} = "x" && x${touser} != "x" ]];then
		curl https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=$token \
		-H 'Content-Type: application/json' \
		-d '{"msgtype":"text","text":{"content":"'"$msg"'","mentioned_mobile_list":['$touser']}}'
	fi
}

program=$(basename $0)
#-o或--options选项后面接可接受的短选项，如ex:s::，表示可接受的短选项为-e -x -s，其中-e选项不接参数，-x选项后必须接参数，-s选项的参数为可选的
#-l或--long选项后面接可接受的长选项，用逗号分开，冒号的意义同短选项。
#-n选项后接选项解析错误时提示的脚本名字["std.sh: unknown option -- d"]
ARGS=$(getopt -a -o am:t: -l msg:,token:,mobile:,all -n "${program}" -- "$@")

#如果参数不正确，打印提示信息
[[ $? -ne 0 ]] && usage && exit 1
[[ $# -eq 0 ]] && usage && exit 1

echo ${ARGS} | grep -E '\-\-token' | grep -E '\-t|\-\-mobile|\-a|\-\-all' | grep -E '\-m|\-\-msg'
[[ $? -ne 0 ]] && echo 缺少参数 && usage && exit 1


#将规范化后的命令行参数分配至位置参数（$1,$2,...)
eval set -- "${ARGS}"
while true
do
	case "$1" in
		-a|--all)
			isAtAll=true
			shift
			;;
		-m|--msg)
			msg="$2"
			shift 2
			;;
		-t|--mobile)
			touser="$2"
			touser=`echo $touser | grep -oE "([0-9]{11})" | xargs echo | sed 's/ /,/' | sed 's#\([0-9]\{11\}\)#"\1"#g'`
			shift 2
			;;
		--token)
			token="$2"
			shift 2
			;;
		--)
			shift
			break
			;;
	esac
done

send_msg