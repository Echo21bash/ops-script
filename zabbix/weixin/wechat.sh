CropID='ww819a5b29a2c7eb36'
Secret='XPBtB3QJjzC3djnbblcGln5bmxMOgsNR6xE8fepTS0M'
GURL="https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid=$CropID&corpsecret=$Secret"

#get acccess_token
token=$(curl -s -G $GURL| awk -F\" '{print $10}')
echo $token
PURL="https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=$token"
#
function body() {
#企业号中的应用id
local int AppID=1000002
#部门成员id，zabbix中定义的微信接收者
local UserID="touser"
#部门id，定义了范围，组内成员都可接收到消息
local PartyID=1
#消息内容
local Msg=这是一条测试消息
printf '{\n'
printf '\t"touser": "'"$UserID"\"",\n"
printf '\t"toparty": "'"$PartyID"\"",\n"
printf '\t"msgtype": "text",\n'
printf '\t"agentid": "'" $AppID "\"",\n"
printf '\t"text": {\n'
printf '\t\t"content": "'"$Msg"\""\n"
printf '\t},\n'
printf '\t"safe":"0"\n'
printf '}\n'
}
/usr/bin/curl --data-ascii "$(body)" $PURL


load_config_file(){

	if [[ -f $optarg ]];then
		. $optarg
	else
		echo "配置文件$optarg不存在"
		exit 1
	fi

}

msg(){
	Msg="$optarg"
}

touser(){
	UserID="$optarg"
}

toparty(){
	PartyID="$optarg"
}

while getopts "f:m:u:p:" arg #选项后面的冒号表示该选项需要参数
do
	case $arg in
		f)
			load_config_file

		m)
			msg

		u)
			touser
			
		p)
			toparty
		?)  #当有不认识的选项的时候arg为?
			echo "unkonw argument"
			exit 1

	esac
done