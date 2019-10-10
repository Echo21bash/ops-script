#!/bin/bash
. /etc/profile
###pubic函数begin
colour_keyword(){
	red='\033[0;31m'
	green='\033[0;32m'
	yellow='\033[0;33m'
	plain='\033[0m'
	info="[${green}info${plain}]"
	warning="[${yellow}warning${plain}]"
	error="[${red}error${plain}]"
}

diy_echo(){
	#$1内容 $2颜色(非必须) $3前缀关键字(非必须)
	if [[ $3 = '' ]];then
		echo -e "$2$1${plain}"
	else
		echo -e "$3 $2$1${plain}"
	fi
}

yes_or_no(){
	#$1变量值
	tmp=$(echo $1 | tr [A-Z] [a-z])
	if [[ $tmp = 'y' || $tmp = 'yes' ]];then
		return 0
	else
		return 1
	fi

}

only_allow_numbers(){
	#$1传入值
	local j=0
	for ((j=0;j<$#;j++))
	do
		tmp=($@)
		if [ -z "$(echo ${tmp[$j]} | sed 's#[0-9]##g')" ];then
			continue
		else
			return 1
		fi
	done
}

input_option(){
	#$1输入描述、$2默认值(支持数组)、$3变量名
	#input_option '选项描述' '默认值' '变量名'
	#变量值为数字可直接使用传入的变量名，若为包含字符需要用${input_value[@]}变量中转否则会被转为0
	diy_echo "$1" "" "${info}"
	stty erase '^H' && read -t 30 -p "请输入(30s后选择默认$2):" input_value
	#变量数组化
	if [[ -z $input_value ]];then
		input_value=(${2})
	else
		input_value=(${input_value})
	fi
	length=${#input_value[@]}

	only_allow_numbers ${input_value[@]}
	if [[ $? = 0 ]];then
		#对数组赋值
		local i
		i=0
		for dd in ${input_value[@]}
		do
			(($3[$i]="$dd"))
			((i++))
		done
	fi
	a=${input_value[@]}
	diy_echo "你的输入是 $(diy_echo "${a}" "${green}")" "" "${info}"
}

output_option(){
#$1选项描述、$2选项、$3变量名
#例output_option '选项描述' '选项一 选项二' '变量名'
	diy_echo "$1" "" "${info}"
	#将字符串分割成数组
	option=($2)
	#数组长度
	length=${#option[@]}
	
	local i
	i=0
	for item in ${option[@]}
	do
		i=`expr ${i} + 1`
		diy_echo "[${green}${i}${plain}] ${item}"
	done
	#清空output
	output=()
	stty erase '^H' && read -t 30 -p "请输入数字(30s后选择默认1):" output
	
	if [[ -z ${output} ]];then
		output=1
	fi
	
	output=(${output})
	only_allow_numbers ${output[@]}
	if [[ $? != '0' ]];then
		diy_echo "输入错误请重新选择" "${red}" "${error}"
		output_option "$1" "$2" "$3"
	fi
	#清空output_value
	output_value=()
	local j
	j=0
	for item in ${output[@]}
	do
		if [[ ${item} -gt '0' && ${item} -le ${length} ]];then
			(($3[$j]=$item))
			i=$(((${item}-1)))
			output_value[$j]=${option[$i]}
		else
			diy_echo "输入错误请重新选择" "${red}" "${error}"
			output_option "$1" "$2" "$3"
		fi
		((j++))
	done
	a=${output_value[@]}
	diy_echo "你的选择是 $(diy_echo "${a}" "${green}")"

}