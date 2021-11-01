#!/bin/bash
###企业微信发送应用消息

usage()
{
	cat <<-EOF
	Usage:${program} [OPTION]...
	--corpid    企业ID（必选）
	--agentid   企业应用ID（必选）
	--corpsecret 企业应用Secret（必选）
	--msg     消息内容（必选）
	--user    发送用户ID（可选）多个使用,分隔
	--partyid 群发部门ID（可选）多个使用,分隔
	EOF
}

get_token(){
	
	get_token_url="https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid=${corpid}&corpsecret=${corpsecret}"
	token=$(curl -s -G $get_token_url | awk -F \" '{print $10}')
	if [[ -z ${token} ]];then
		echo "获取token失败"
		exit 1
	fi
}

send_msg(){

	msg="`echo ${msg} | sed 's/"/\\\\"/g'`"
	if [[ x${partyid} != "x" && x${user} != "x" ]];then
		send_status=`curl -s https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=$token \
		-H 'Content-Type: application/json' \
		-d '{"agentid": "'$agentid'","toparty":"'$partyid'","touser":"'$user'","msgtype":"text","text":{"content":"'$msg'"}}' | \
		grep -oE '"errcode":[0-9]{1,}' | grep -oE '[0-9]{1,}'`
		exit ${send_status}

	fi

	if [[ x${partyid} = "x" && x${user} != "x" ]];then
		send_status=`curl -s https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=$token \
		-H 'Content-Type: application/json' \
		-d '{"agentid": "'$agentid'","touser":"'$user'","msgtype":"text","text":{"content":"'$msg'"}}' | \
		grep -oE '"errcode":[0-9]{1,}' | grep -oE '[0-9]{1,}'`
		exit ${send_status}
	fi
}

program=$(basename $0)
#-o或--options选项后面接可接受的短选项，如ex:s::，表示可接受的短选项为-e -x -s，其中-e选项不接参数，-x选项后必须接参数，-s选项的参数为可选的
#-l或--long选项后面接可接受的长选项，用逗号分开，冒号的意义同短选项。
#-n选项后接选项解析错误时提示的脚本名字["std.sh: unknown option -- d"]
ARGS=$(getopt -o -a -l corpid:,agentid:,corpsecret:,msg:,user,partyid -n "${program}" -- "$@")
#如果参数不正确，打印提示信息
[[ $? -ne 0 ]] && usage && exit 1
[[ $# -eq 0 ]] && usage && exit 1

echo ${ARGS} | grep -E '\-\-corpid' | grep -E '\-\-agentid' | grep -E '\-\-corpsecret' | grep -E '\-\-msg' | grep -E '\-\-user|\-\-partyid'
[[ $? -ne 0 ]] && echo 缺少参数 && usage && exit 1


#将规范化后的命令行参数分配至位置参数（$1,$2,...)
eval set -- "${ARGS}"
while true
do
	case "$1" in
		--corpid)
			corpid="$2"
			shift 2
			;;
		--agentid)
			agentid="$2"
			shift 2
			;;
		--corpsecret)
			corpsecret="$2"
			shift 2
			;;
		--msg)
			msg="$2"
			shift 2
			;;
		--user)
			user="$2"
			user=`echo ${user} | grep -oE "([a-z]{1,})" | xargs echo | sed 's/ /|/' | sed 's#\([a-z]\{1,\}\)#\1#g'`
			shift 2
			;;
		--partyid)
			partyid="$2"
			partyid=`echo ${partyid} | grep -oE "([0-9]{1,})" | xargs echo | sed 's/ /|/' | sed 's#\([0-9]\{1,\}\)#\1#g'`
			shift 2
			;;
		--)
			shift
			break
			;;
		*)
			echo usage
			exit 1
			;;
	esac
done

get_token
send_msg