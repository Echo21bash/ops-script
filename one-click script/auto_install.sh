#!/bin/bash
###########################################################
#System Required: Centos 6+
#Description: Install the java tomcat mysql and tools
#Version: 2.0
#                                                        
#                            by---wang2017.7
###########################################################
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

sys_info(){

	if [ -f /etc/redhat-release ]; then
		if cat /etc/redhat-release | grep -Eqi "Centos";then
			sys_name="Centos"
		elif cat /etc/redhat-release | grep -Eqi "red hat" || cat /etc/redhat-release | grep -Eqi "redhat";then
			sys_name="Red-hat"
		fi
    elif cat /etc/issue | grep -Eqi "debian"; then
        sys_name="Debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        sys_name="Ubuntu"
    elif cat /etc/issue | grep -Eqi "Centos"; then
        sys_name="Centos"
    elif cat /etc/issue | grep -Eqi "red hat|redhat"; then
        sys_name="Red-hat"
	fi
#版本号
    if [[ -s /etc/redhat-release ]]; then
		release_all=`grep -oE  "[0-9.0-9]+" /etc/redhat-release`
		os_release=${release_all%%.*}
		else
		release_all=`grep -oE  "[0-9.]+" /etc/issue`
		os_release=${release_all%%.*}
    fi
#系统位数
	os_bit=`getconf LONG_BIT`
#内核版本
	kel=`uname -r | grep -oE [0-9]{1}.[0-9]{1,\}.[0-9]{1,\}-[0-9]{1,\}`
  ping -c 1 www.baidu.com >/dev/null 2>&1
  if [ $? = '0' ];then
    network_status="${green}connected${plain}"
  else
    network_status="${red}disconnected${plain}"
  fi
  diy_echo "Your machine is:${sys_name}"-"${release_all}"-"${os_bit}-bit.\n${info} The kernel version is:${kel}.\n${info} Network status:${network_status}" "" "${info}"
  [[ ${sys_name} = "red-hat" ]] && sys_name="Centos"

}

get_ip(){
	local_ip=$(ip addr | grep -E 'eth[0-9]{1}|eno[0-9]{1,}|ens[0-9]{1,}' | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v  "^255\.|\.255$|^127\.|^0\." | head -n 1)
}

get_public_ip(){
	public_ip=$(curl ipv4.icanhazip.com)
}

get_net_name(){
	net_name=$(ip addr | grep -oE 'eth[0-9]{1}|eno[0-9]{1,}|ens[0-9]{1,}' | head -n 1)
}

sys_info_detail(){
  sys_info
  #系统开机时间
  echo -e "${info} System boot time:"
  date -d "$(awk '{printf("%d\n",$1~/./?int($1)+1:$1)}' /proc/uptime) second ago" +"%F %T"
  #系统已经运行时间
  echo -e "${info} The system is already running:"
  awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60;d=$1%60}{printf("%d天%d时%d分%d秒\n",a,b,c,d)}' /proc/uptime
  #CPU型号
  echo -e "${info} CPU型号:"
  awk -F':[ ]' '/model name/{printf ("%s\n",$2);exit}' /proc/cpuinfo
  #CPU详情
  echo -e "${info} CPU详情:"
  awk -F':[ ]' '/physical id/{a[$2]++}END{for(i in a)printf ("%s号CPU\t核心数:%s\n",i+1,a[i]);printf("CPU总颗数:%s\n",i+1)}' /proc/cpuinfo
  #ip
  echo -e "${info} 内网IP:"
  hostname -I 2>/dev/null
  [[ $? != "0" ]] && hostname -i
  echo -e "${info} 网关:"
  netstat -rn | awk '/^0.0.0.0/ {print $2}'
  echo -e "${info} 外网IP:"
  curl -s icanhazip.com
  #内存使用情况
  echo -e "${info} 内存使用情况(MB):参考[可用内存=free的内存+cached的内存+buffers的内存]"
  free -m 
  (( ${os_release} < "7" )) && free -m | grep -i Mem | awk '{print "总内存是:"$2"M,实际使用内存是:"$2-$4-$5-$6-$7"M,实际可用内存是:"$4+$6+$7"M,内存使用率是:"(1-($4+$6+$7)/$2)*100"%"}' 
  (( ${os_release} >= "7" )) && free -m | grep -i Mem | awk '{print "总内存是:"$2"M,实际使用内存是:"$2-$4-$5-$6"M,实际可用内存是:"$4+$6"M,内存使用率是:"(1-($4+$6)/$2)*100"%"}'
  free -m | grep -i Swap| awk '{print "总Swap大小:"$2"M,已使用的大小:"$3"M,可用大小:"$4"M,Swap使用率是:"$3/$2*100"%"}' 
  #磁盘使用情况
  echo -e "${info} 磁盘使用情况:"
  df -h
  #服务器负载情况
  echo -e "${info} 服务器平均负载:"
  uptime | awk '{print $(NF-4)" "$(NF-3)" "$(NF-2)" "$(NF-2)" "$NF}'
  #当前在线用户
  echo -e "${info} 当前在线用户:"
  who

}

auto_ssh_keygen(){
	expect_dir=`which expect 2>/dev/null`
	[ -z ${expect_dir} ] && yum install expect -y
	input_option "请输入ssh互信主机的信息,格式ip:port:passwd(多个空格隔开)" "127.0.0.1:22:root:123456" "ssh_ip"
	ssh_ip=(${input_value[@]})
	[ ! -f /root/.ssh/id_rsa ] && ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa -q
	for ip in ${ssh_ip[@]}
	do
		addr=`echo $ip | awk -F : '{print $1}'`
		port=`echo $ip | awk -F : '{print $2}'`
		user=`echo $ip | awk -F : '{print $3}'`
		passwd=`echo $ip | awk -F : '{print $4}'`
		expect <<-EOF
		spawn ssh-copy-id -i /root/.ssh/id_rsa.pub ${user}@${addr} -p ${port}
		expect {
			"yes/no" {send "yes\r";exp_continue}
			"password:" {send "$passwd\r";exp_continue}
        }
		EOF
	done
}
###pubic函数end

###系统优化begin
system_optimize_set(){
	output_option "选择需要优化的项(可多选)" "\
	 替换为国内YUM源\
	 优化最大限制\
	 优化SSHD服务\
	 系统时间同步\
	 优化内核参数\
	 关闭SElinux\
	 关闭非必须服务\
	 设置shell终端参数\
	 锁定系统关键文件\
	 全部优化" "conf"

	for conf in ${conf[@]}
	do
		case "$conf" in
			1)system_optimize_yum
			;;
			2)system_optimize_Limits
			;;
			3)system_optimize_sshd
			;;
			4)system_optimize_systime
			;;
			5)system_optimize_kernel
			;;
			6)system_optimize_selinux
			;;
			7)system_optimize_service
			;;
			8)system_optimize_profile
			;;
			9)system_optimize_permission
			;;
		esac
	done
}

system_optimize_yum(){
	diy_echo "添加必要yum源,并安装必要的命令..." "" "${info}"
	[[ ! -f /etc/yum.repos.d/CentOS-Base.repo.backup ]] && cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup

	if [[ ${os_release} < "7" ]];then
		[[ ! -f /etc/yum.repos.d/epel.repo ]] && \
		wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-6.repo >/dev/null 2>&1
		[[ -z 'grep mirrors.aliyun.com /etc/yum.repos.d/CentOS-Base.repo' ]] && \
		wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-6.repo >/dev/null 2>&1
		yum clean all >/dev/null 2>&1
	else
		[[ ! -f /etc/yum.repos.d/epel.repo ]] && \
		wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo >/dev/null 2>&1
		[[ -z 'grep mirrors.aliyun.com /etc/yum.repos.d/CentOS-Base.repo' ]] && \
		wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo >/dev/null 2>&1
		yum clean all >/dev/null 2>&1
	fi
	yum -y install bash-completion wget chrony vim
	if [ $? -eq 0 ];then
		diy_echo "添加完成yum源,并安装必要的命令..." "" "${info}"
	else
		diy_echo "更新yum源失败请检查网络!" "" "${error}"
	fi
}

system_optimize_Limits(){
	echo -e "${info} Removing system process and file open limit..."
	LIMIT=`grep nofile /etc/security/limits.conf |grep -v "^#"|wc -l`
	if [ $LIMIT -eq 0 ];then
		[ ! -f /etc/security/limits.conf.bakup ] && cp /etc/security/limits.conf /etc/security/limits.conf.bakup
		echo '*                  -        nofile         65536'>>/etc/security/limits.conf
		echo '*                  -        nproc          65536'>>/etc/security/limits.conf
		[ -f /etc/security/limits.d/20-nproc.conf ] && sed -i 's/*          soft    nproc     4096/*          soft    nproc     65536/' /etc/security/limits.d/20-nproc.conf
		ulimit -HSn 65536
		if [ $? -eq 0 ];then
			echo -e "${info} Remove system process and file open limit successfully"
		else
			echo -e "${error} Failed to remove system process and file open limit"
		fi
	fi
  #Centos7对于systemd service的资源设置，则需修改全局配置，全局配置文件放在/etc/systemd/system.conf和/etc/systemd/user.conf，同时也会加载两个对应目录中的所有.conf文件/etc/systemd/system.conf.d/*.conf和/etc/systemd/user.conf.d/*.conf。system.conf是系统实例使用的，user.conf是用户实例使用的。
	if [[ -f /etc/systemd/system.conf ]];then
		[[ ! -f /etc/systemd/system.conf.bakup ]] && cp /etc/systemd/system.conf /etc/systemd/system.conf.bakup
		sed -i 's/#DefaultLimitNOFILE=/DefaultLimitNOFILE=65536/' /etc/systemd/system.conf
		sed -i 's/#DefaultLimitNPROC=/DefaultLimitNPROC=65536/' /etc/systemd/system.conf
	fi
	if [[ -f /etc/systemd/user.conf ]];then
		[[ ! -f /etc/systemd/user.conf.bakup ]] && cp /etc/systemd/user.conf /etc/systemd/user.conf.bakup
		sed -i 's/#DefaultLimitNOFILE=/DefaultLimitNOFILE=65536/' /etc/systemd/user.conf
		sed -i 's/#DefaultLimitNPROC=/DefaultLimitNPROC=65536/' /etc/systemd/user.conf
	fi
}

system_optimize_sshd(){
	echo -e "${info} Modifing ssh default parameters..."
	[ ! -f /etc/ssh/sshd_config.bakup ] && cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bakup
	sed -i 's/#Port 22/Port 52233/g' /etc/ssh/sshd_config
	sed -i 's/^#LogLevel INFO/LogLevel INFO/g' /etc/ssh/sshd_config
	sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/g' /etc/ssh/sshd_config
	#sed -i 's/#PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
	sed -i 's/^GSSAPIAuthentication yes/GSSAPIAuthentication no/' /etc/ssh/sshd_config 
	sed -i 's/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config
	echo '+-------modify the sshd_config-------+'
	echo 'Port 52233'
	echo 'LogLevel INFO'
	echo 'PermitEmptyPasswords no'
	#echo 'PermitRootLogin no'
	echo 'UseDNS no'
	echo '+------------------------------------+'
	if [[ ${os_release} < '7' ]];then
		/etc/init.d/sshd reload >/dev/null 2>&1 && echo -e "${info} Modify ssh default parameters successfully" || echo -e "${error} Failed to modify ssh default parameters"
	else
		systemctl restart sshd && echo -e "${info} Modify ssh default parameters successfully" || echo -e "${error} Failed to modify ssh default parameters"
	fi
}

system_optimize_systime(){
	echo -e "${info} Synchronizing system time..."
	rm -rf /etc/localtime
	ln -sfn /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	NTPDATE=`grep ntpdate /var/spool/cron/root 2>/dev/null |wc -l`
	if [ $NTPDATE -eq 0 ];then
		echo "#times sync by lee at bakup" >>/var/spool/cron/root
		echo "0 */2 * * * /usr/sbin/ntpdate time.pool.aliyun.com >/dev/null 2>&1" >> /var/spool/cron/root
		ntpdate time.pool.aliyun.com > /dev/null 2>&1
		if [ $? -eq 0 ];then
			echo -e "${info} Configuration time synchronization completed"
		else
			echo -e "${error} Configuration time synchronization failed"
		fi
	fi
}

system_optimize_kernel(){
	echo -e "${info} Optimizing kernel parameters"
	[ ! -f /etc/sysctl.conf.bakup ] && cp /etc/sysctl.conf /etc/sysctl.conf.bakup
	[[ -z `grep -E '^net.ipv4.tcp_fin_timeout' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_fin_timeout = 10'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_keepalive_time' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_keepalive_time = 600'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_tw_reuse' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_tw_reuse = 1'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_tw_recycle' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_tw_recycle = 0'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_syncookies' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_syncookies = 1'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_syn_retries' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_syn_retries = 1'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.ip_local_port_range' /etc/sysctl.conf` ]] && echo 'net.ipv4.ip_local_port_range = 4000 65000'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_max_syn_backlog' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_max_syn_backlog = 16384'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.core.somaxconn' /etc/sysctl.conf` ]] && echo 'net.core.somaxconn = 16384'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.tcp_max_tw_buckets' /etc/sysctl.conf` ]] && echo 'net.ipv4.tcp_max_tw_buckets = 36000'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.ipv4.route.gc_timeout' /etc/sysctl.conf` ]] && echo 'net.ipv4.route.gc_timeout = 100'>>/etc/sysctl.conf
	[[ -z `grep -E '^net.core.netdev_max_backlog' /etc/sysctl.conf` ]] && echo 'net.core.netdev_max_backlog = 16384'>>/etc/sysctl.conf
	[[ -z `grep -E '^vm.max_map_count' /etc/sysctl.conf` ]] && echo 'vm.max_map_count = 262144'>>/etc/sysctl.conf
	[[ -z `grep -E '^vm.swappiness' /etc/sysctl.conf` ]] && echo 'vm.swappiness = 0'>>/etc/sysctl.conf


	sysctl -p>/dev/null 2>&1
	echo -e "${info} Optimize kernel parameter completion"
}

system_optimize_selinux(){
  
	echo -e "${info} Disabling selinux and closing the firewall..."
	[ ! -f /etc/selinux/config.bakup ] && cp /etc/selinux/config /etc/selinux/config.bakup
	[[ ${os_release} < "7" ]] && /etc/init.d/iptables stop >/dev/null
	[[ ${os_release} > "6" ]] && systemctl stop firewalld.service >/dev/null
	sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	setenforce 0
	if [ ! -z `grep SELINUX=disabled /etc/selinux/config` ];then
		echo -e "${info} Disable selinux and close the firewall to complete"
	else
		echo -e "${error} Disabling selinux and shutting down the firewall failed"
	fi
}

system_optimize_service(){
	echo -e "${info} Slashing startup items..."
	if [[ ${os_release} < "7" ]];then
		for A in `chkconfig --list |grep -E '3:on|3:启用' |awk '{print $1}' `
		do
			chkconfig $A off
		done
		for A in rsyslog network sshd crond;do chkconfig $A on;done
	else
		for A in `systemctl list-unit-files|grep enabled |awk '{print $1}'`
		do 
			systemctl disable $A >/dev/null
		done
		for A in rsyslog network sshd crond;do systemctl enable $A;done
	fi
	diy_echo "精简开机自启动完成" "" "${info}"
}

system_optimize_profile(){
	echo -e "${info} 设置默认历史记录数和连接超时时间..."
	if [ -z `grep TMOUT=600 /etc/profile` ];then
		echo "TMOUT=600" >>/etc/profile
		echo "HISTSIZE=10" >>/etc/profile
		echo "HISTFILESIZE=10" >>/etc/profile
		source /etc/profile
		echo -e "${info} 设置默认历史记录数和连接超时时间完成"
	fi
}

system_optimize_permission(){
	#锁定关键文件系统
	chattr +i /etc/passwd
	chattr +i /etc/inittab
	chattr +i /etc/group
	chattr +i /etc/shadow
	chattr +i /etc/gshadow
	/bin/mv /usr/bin/chattr /usr/bin/lock
	sed -i 's#^exec.*# #exec /sbin/shutdown -r now "Control-Alt-Delete pressed"#'/etc/init/control-alt-delete.conf
	echo -e "${info} 锁定关键文件系统完成"
}
###系统优化end
install_version(){
	#需要传参$1软件名称
	soft_name="$1"
	version='_version'
	java_version=('7' '8')
	node_version=('9' '10')
	ruby_version=('2.3' '2.4')
	tomcat_version=('7' '8')
	mysql_version=('5.5' '5.6' '5.7')
	mongodb_version=('3.4' '3.6' '4.0')
	nginx_version=('1.14' '1.15' '1.16')
	php_version=('5.6' '7.0' '7.1')
	redis_version=('3.2' '4.0' '5.0')
	memcached_version=('1.4' '1.5')
	zookeeper_version=('3.4')
	kafka_version=('2.2')
	activemq_version=('5.13' '5.14' '5.15')
	rocketmq_version=('4.2' '4.3')
	hadoop_version=('2.9' '3.0' '3.1')
	zabbix_version=('3.4' '4.0')
	elasticsearch_version=('5.6' '6.1' '6.2')
	logstash_version=('5.6' '6.1' '6.2')
	kibana_version=('5.6' '6.1' '6.2')
	filebeat_version=('5.6' '6.1' '6.2')
	k8s_version=('1.11' '1.12' '1.13' '1.14')
	program_version=`eval echo '$'{$soft_name$version[@]}`
	output_option "请选择${soft_name}版本" "${program_version[@]}" "version_number"
	version_number=${output_value}
}

install_selcet(){
	output_option "请选择安装方式版本" "在线安装 本地安装" "install_mode"
}

local_install(){

	while true
	do
		[ ${os_bit} = 64 ] && echo -e "${info} 请输入${soft_name}64位安装包路径(如:/opt/xxx-x64.tar.gz)"
		[ ${os_bit} = 32 ] && echo -e "${info} 请输入${soft_name}32位安装包路径(如:/opt/xxx-i586.tar.gz)"

		stty erase '^H' && read user_inpt
		if [  -f "$user_inpt" ];then
			cd ${install_dir}
			echo -e "${info} Copying compressed package, please wait" && \cp  ${user_inpt}  ${install_dir}/${file_name} && break
		else
			echo -e "${error} File does not exist, please enter the correct path"
		fi
	done
}

online_url(){

	java_url='https://repo.huaweicloud.com/java/jdk'
	java_url="http://mirrors.linuxeye.com/jdk"
	ruby_url="http://mirrors.ustc.edu.cn/ruby"
	node_url="http://mirrors.ustc.edu.cn/node"
	#tomcat_url="http://archive.apache.org/dist/tomcat"
	tomcat_url="http://mirrors.ustc.edu.cn/apache/tomcat"

	#mysql_url=('http://mirrors.ustc.edu.cn/mysql-ftp/Downloads' 'http://mirrors.163.com/mysql/Downloads')
	mysql_url='http://mirrors.163.com/mysql/Downloads'
	mysql_galera_url='http://releases.galeracluster.com'
	mongodb_url="https://www.mongodb.org/dl/linux"
	nginx_url="http://nginx.org/download"
	php_url="http://mirror.cogentco.com/pub/php"
	php_url="http://mirrors.sohu.com/php/"
	
	redis_url="https://mirrors.huaweicloud.com/redis"
	memcached_url='https://github.com/memcached/memcached'
	memcached_url="https://mirrors.huaweicloud.com/memcached"
	zookeeper_url="http://mirrors.ustc.edu.cn/apache/zookeeper"
	kafka_url='http://mirrors.ustc.edu.cn/apache/kafka'
	activemq_url="https://mirrors.huaweicloud.com/apache/activemq"
	rocketmq_url="http://mirrors.ustc.edu.cn/apache/rocketmq"
	hadoop_url="http://mirrors.ustc.edu.cn/apache/hadoop/common"
	fastdfs_url='https://github.com/happyfish100/fastdfs'
	minio_url='https://dl.minio.io/server/minio/release/linux-amd64/minio'
	elasticsearch_url='https://mirrors.huaweicloud.com/elasticsearch'
	logstash_url='https://mirrors.huaweicloud.com/logstash'
	kibana_url='https://mirrors.huaweicloud.com/kibana'
	filebeat_url='https://mirrors.huaweicloud.com/filebeat'
	zabbix_url='https://sourceforge.mirrorservice.org/z/za/zabbix/ZABBIX%20Latest%20Stable'
	grafana_url='https://mirrors.huaweicloud.com/grafana'
	#url=($(eval echo '$'{${soft_name}_url[@]}))
	url=$(eval echo '$'{${soft_name}_url})
}

online_version(){

	all_version_general(){
		curl -Ls -o /tmp/all_version ${url} >/dev/null 2>&1
	}
	
	all_version_other(){
	case "$soft_name" in
		mysql)
			if [[ ${branch} = '1' ]];then
				curl -sL ${mysql_url}/MySQL-${version_number} >/tmp/all_version
			else
				curl -sL ${mysql_galera_url}/mysql-wsrep-${version_number}/binary >/tmp/all_version
			fi
		;;
		mongodb)
			wget ${url}/x86_64-${version_number} -O /tmp/all_version >/dev/null 2>&1
		;;
		tomcat)
			wget ${url}/${soft_name}-${version_number} -O /tmp/all_version >/dev/null 2>&1
		;;
		k8s)
			yum list --showduplicates kubeadm >/tmp/all_version
		;;
	esac
	}

	ver_rule_general(){
		option=$(cat /tmp/all_version | grep -Eio "${version_number}\.[0-9]{1,2}" | sort -u -n  -k 3 -t '.' )
	}

	ver_rule_general1(){
		option=$(cat /tmp/all_version | grep -Eio "${version_number}\.[0-9]{1,2}\.[0-9]{1,2}" | sort -u -n  -k 3 -t '.' )
	}

	ver_rule_general2(){
		option=$(cat /tmp/all_version | grep -Eio "${soft_name}-${version_number}.[0-9]{1,2}" | sort -u -n  -k 3 -t '.' )
	}
	
	ver_rule_last_rev(){
		option='latest version'
	}
	
	ver_rule_other(){
	
		case "$soft_name" in
		java)
			if [[ ${os_bit} = '64' ]];then
				option=$(cat /tmp/all_version | grep -Eio "jdk-${version_number}u.*x64" | sort -u)
			else
				option=$(cat /tmp/all_version | grep -Eio "jdk-${version_number}u.*i586" | sort -u)
			fi
		;;
		node)
			option=$(cat /tmp/all_version | grep -Eio "${version_number}\.[0-9]{1,2}\.[0-9]{1,2}" | sort -u -n  -k 2 -t '.')
		;;
	esac

	}


	diy_echo "正在获取在线版本..." "" "${info}"
	#generated_version
	case "$soft_name" in
		node|nginx|redis|memcached|php|zookeeper|kafka|activemq|rocketmq|zabbix|elasticsearch|logstash|kibana|filebeat|grafana)
			all_version_general
		;;
		java)
			wget ${url}/md5sum.txt -O /tmp/all_version >/dev/null 2>&1
		;;
		ruby)
			wget ${url}/${version_number} -O /tmp/all_version >/dev/null 2>&1
		;;
		mysql|mongodb|tomcat|k8s)
			all_version_other
		;;

	esac

	#ver_rule
	case "$soft_name" in
		ruby|mysql|mongodb|zookeeper|kafka|activemq|rocketmq|elasticsearch|logstash|kibana|filebeat|zabbix|k8s|grafana)
			ver_rule_general
		;;
		tomcat)
			ver_rule_general1
		;;
		nginx|redis|memcached|php)
			ver_rule_general2
		;;
		fastdfs|minio)
			ver_rule_last_rev
		;;
		java|node)
			ver_rule_other
		;;
	esac

	output_option '请选择在线版本号' "${option}" 'online_select_version'
	[ -z ${online_select_version} ] && diy_echo "镜像站没有该版本" "$red" "$error" && exit 1
	online_select_version=(${output_value[@]})
	diy_echo "按任意键继续" "${yellow}" "${info}"
	read
}

online_down(){
	#拼接下载链接
	case "$soft_name" in
		java|nginx|redis|memcached|php)
			down_url="${url}/${online_select_version}.tar.gz"
		;;
		ruby)
			down_url="${url}/${soft_name}-${online_select_version}.tar.gz"
		;;
		elasticsearch|logstash)
			down_url="${url}/${online_select_version}/${soft_name}-${online_select_version}.tar.gz"
		;;
		kibana|filebeat)
			if [[ ${os_bit} = '64' ]];then
				down_url="${url}/${online_select_version}/${soft_name}-${online_select_version}-linux-x86_64.tar.gz"
			else
				down_url="${url}/${online_select_version}/${soft_name}-${online_select_version}-linux-x86.tar.gz"
			fi
		;;
		node)
			down_url="${url}/v${online_select_version}/node-v${online_select_version}-linux-x64.tar.gz"
		;;
		mysql)
			if [[ ${branch} = '1' ]];then
				[[ ${os_bit} = '64' ]] && down_url="${url}/MySQL-${version_number}/mysql-${online_select_version}-linux-glibc2.12-x86_64.tar.gz"
				[[ ${os_bit} = '32' ]] && down_url="${url}/MySQL-${version_number}/mysql-${online_select_version}-linux-glibc2.12-i686.tar.gz"
			else
				[[ ${os_bit} = '64' ]] && down_url="${mysql_galera_url}/mysql-wsrep-${version_number}/binary/mysql-wsrep-${online_select_version}-`cat /tmp/all_version | grep -Eio "[0-9]{2}\.[0-9]{2}" | sort -u`-linux-x86_64.tar.gz"
			fi
		;;
		mongodb)
			down_url="http://downloads.mongodb.org/linux/mongodb-linux-x86_64-${online_select_version}.tgz"
		;;
		tomcat)
			down_url="${url}/tomcat-${version_number}/v${online_select_version}/bin/apache-tomcat-${online_select_version}.tar.gz"
		;;
		zookeeper)
			down_url="${url}/zookeeper-${online_select_version}/zookeeper-${online_select_version}.tar.gz"
		;;
		kafka)
			down_url="${url}/${online_select_version}/kafka_2.11-${online_select_version}.tgz"
		;;
		activemq)
			down_url="${url}/${online_select_version}/apache-activemq-${online_select_version}-bin.tar.gz"
		;;
		rocketmq)
			down_url="${url}/${online_select_version}/rocketmq-all-${online_select_version}-bin-release.zip"
		;;
		fastdfs)
			down_url="${url}/archive/master.tar.gz"
		;;
		minio)
			down_url="${url}"
		;;
		zabbix)
			down_url="${url}/${online_select_version}/zabbix-${online_select_version}.tar.gz"
		;;
		grafana)
			down_url="${url}/${online_select_version}/${soft_name}-${online_select_version}.linux-amd64.tar.gz"
		;;
	esac

	cd ${install_dir} && wget ${down_url} -O ${file_name}
  if [ $? = '0' ];then
		diy_echo "${online_select_version}下载完成..." "" "${info}"
	else
		diy_echo "${online_select_version}下载失败..." "${red}" "${error}"
		exit 1
	fi
}

install_dir_set(){
	#需要传参$1软件名称
	[[ -z ${soft_name} ]] && soft_name="$1"
	input_option "请输入安装路径" "/opt" "install_dir"
	install_dir=${input_value}
	pdir=$(dirname ${install_dir}) && bdir=$(basename ${install_dir})

	if [[ ${pdir} = '/' ]];then
		install_dir="${pdir}${bdir}"
	else
		install_dir="${pdir}/${bdir}"
	fi
	[[ ! -d ${install_dir} ]] && mkdir -p ${install_dir}
	#判断是否存在已有目录
	home_dir=${install_dir}/${soft_name}
	if [[ ! -d ${home_dir} ]];then
		mkdir -p ${home_dir}
	else
		diy_echo "Already existing folders${home_dir},Please check!" "" "${error}"
		exit 1
	fi
}

download_unzip(){

	if [[ ${soft_name} = 'rocketmq' ]];then
		file_name="${soft_name}.zip"
	elif [[ ${soft_name} = 'mongodb' ]];then
		file_name="${soft_name}.tgz"
	elif [[ ${soft_name} = 'minio' ]];then
		file_name="${soft_name}-release"
	else
		file_name="${soft_name}.tar.gz"
	fi
	
	if [ ${install_mode} = 1 ];then
		online_url
		online_version
		online_down
	elif [ ${install_mode} = 2 ];then
		local_install
	fi
	#获取文件类型
	file_type=$(file -b ${install_dir}/${file_name} | grep -ioEw "gzip|zip|executable|text" | tr [A-Z] [a-z])
	#获取文件目录
	if [[	${file_type} = 'gzip' ]];then
		dir_name=$(tar -tf ${install_dir}/${file_name}  | awk 'NR==1' | awk -F '/' '{print $1}' | sed 's#/##')
	elif [[ ${file_type} = 'zip' ]];then
		dir_name=$(unzip -v ${install_dir}/${file_name} | awk '{print $8}'| awk 'NR==4' | sed 's#/##')
	elif [[ ${file_type} = 'executable' ]];then
		dir_name=${soft_name}
	fi

	#解压文件
	diy_echo "Unpacking the file,please wait..." "" "${info}"
	if [[	${file_type} = 'gzip' ]];then
		tar -zxf ${install_dir}/${file_name} -C ${install_dir}
	elif [[ ${file_type} = 'zip' ]];then
		unzip -q ${install_dir}/${file_name} -d ${install_dir}
	fi
	
	if [[ $? = '0' ]];then
		diy_echo "Unpacking the file success." "" "${info}"
		tar_dir=${install_dir}/${dir_name}
	else
		diy_echo "Unpacking the file failed!" "" "${error}"
		exit 1
	fi

}

check_java(){
	#检查旧版本
	echo -e "${info} 正在检查预装openjava..."
	j=`rpm -qa | grep  java | awk 'END{print NR}'`
	#卸载旧版
	if [ $j -gt 0 ];then
		echo -e "${info} java卸载清单:"
		for ((i=1;i<=j;i++));
		do		
			a1=`rpm -qa | grep java | awk '{if(NR == 1 ) print $0}'`
			echo $a1
			rpm -e --nodeps $a1
		done
		if [ $? = 0 ];then
			echo -e "${info} 卸载openjava完成."
		else
			echo -e "${error} 卸载openjava失败，请尝试手动卸载."
			exit 1
		fi
	else
		echo -e "${info} 该系统没有预装openjava."
	fi
}

install_java(){
	check_java
	mv ${tar_dir}/* ${home_dir}
	add_sys_env "JAVA_HOME=${home_dir} JAVA_BIN=\$JAVA_HOME/bin JAVA_LIB=\$JAVA_HOME/lib CLASSPATH=.:\$JAVA_LIB/tools.jar:\$JAVA_LIB/dt.jar PATH=\$JAVA_HOME/bin:\$PATH"
	java -version
	if [ $? = 0 ];then
		echo -e "${info} JDK环境搭建成功."
	else
		echo -e "${error} JDK环境搭建失败."
		exit 1
	fi
}

java_install_ctl(){
	install_version java
	install_selcet
	install_dir_set
	download_unzip
	install_java
	clear_install
}

ruby_install_set(){
	output_option "请选择安装方式" "编译安装 RVM安装" "install_method"
}

ruby_install(){
	if [[ ${install_method} = '1' ]];then
		install -y zlib-devel openssl-devel
		cd ${tar_dir}
		./configure --prefix=${home_dir}  --disable-install-rdoc
		make && make install
		add_sys_env "PATH=${home_dir}/bin:\$PATH"

	else
		gpg2 --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
		curl -L get.rvm.io | bash -s stable
		source /etc/profile.d/rvm.sh
		rvm install ${version_number}
		rvm use ${version_number} --default
	fi
	gem sources --add http://gems.ruby-china.com/ --remove http://rubygems.org/
	ruby -v
	if [ $? = 0 ];then
		echo -e "${info} ruby环境搭建成功."
	else
		echo -e "${error} ruby环境搭建失败."
		exit 1
	fi
}

ruby_install_ctl(){
	install_version ruby
	ruby_install_set
	if [[ ${install_method} = '1' ]];then
		install_selcet
		install_dir_set
		download_unzip
	fi
	ruby_install
	clear_install
}

node_install(){

	mv ${tar_dir}/* ${home_dir}
	add_sys_env "NODE_HOME=${home_dir} PATH=\${NODE_HOME}/bin:\$PATH"
	${home_dir}/bin/npm config set registry https://registry.npm.taobao.org
}

node_install_ctl(){
	install_version node
	install_selcet
	install_dir_set
	download_unzip
	node_install
	clear_install
}

tomcat_set(){
	input_option "请输入部署个数" "1" "tomcat_num"
	[[ ${tomcat_num} > 1 ]] && diy_echo "部署多个tomcat服务一定要避免端口冲突" "${yellow}" "${warning}"
}

tomcat_other_set(){
		input_option "设置Tomcat文件夹名称,注意不要和现有的冲突" "tomcat" "home_dir_name"
		home_dir_name=${input_value}
		input_option "请输入service服务名称" "tomcat" "service_name"
		service_name=${input_value}
		input_option "请输入http端口号" "8080" "http_port"

}

tomcat_install(){

	for ((i=1;i<=tomcat_num;i++));
	do
		echo -e "${info} 开始设置第${i}个Tomcat."
		tomcat_other_set
		home_dir=${install_dir}/${home_dir_name}
		[ ! -d ${home_dir} ] && mkdir -p ${home_dir}
		\cp -rp ${tar_dir}/* ${install_dir}/${home_dir_name}
		tomcat_config
		tomcat_manager_config
		memory_overflow_config
		add_tomcat_service
		echo -e "${info} 好的设置好${i}个Tomcat了."
	done

}

tomcat_config(){
	#修改配置参数
	cat >/tmp/tmp.server.xml<<-EOF
	               maxThreads="600"
	               minSpareThreads="100"
	               acceptorThreadCount="4"
	               acceptCount="500"
	               enableLookups="false"
	               URIEncoding="UTF-8" />
	EOF

	sed -i '/<Connector port="8080" protocol="HTTP\/1.1"/,/redirectPort="8443" \/>/s/redirectPort="8443" \/>/redirectPort="8443"/' ${home_dir}/conf/server.xml
	sed -i '/^               redirectPort="8443"$/r /tmp/tmp.server.xml' ${home_dir}/conf/server.xml
	sed -i '/<\/Host>/i \      <!--<Context path="" docBase="" reloadable="true">\n      <\/Context>-->' ${home_dir}/conf/server.xml

  #禁用shutdown端口
  sed -i 's/<Server port="8005"/<Server port="-1"/' ${home_dir}/conf/server.xml
  #注释AJP
  sed -i 's#<Connector port="8009".*#<!-- <Connector port="8009" protocol="AJP/1.3" redirectPort="8443" /> -->#' ${home_dir}/conf/server.xml
 	#修改http端口
  sed -i 's/<Connector port="8080"/<Connector port="'${http_port}'"/' ${home_dir}/conf/server.xml
  #日志切割
	add_log_cut ${home_dir_name} ${home_dir}/logs/catalina.out
}

tomcat_manager_config(){
	N=`cat -n ${home_dir}/conf/tomcat-users.xml | grep '</tomcat-users>' | awk '{print $1}'`
	sed -i ''$N'i<role rolename="manager-gui"/>' ${home_dir}/conf/tomcat-users.xml
	sed -i ''$N'i<role rolename="admin-gui"/>' ${home_dir}/conf/tomcat-users.xml
	sed -i ''$N'i<user username="admin" password="admin" roles="manager-gui,admin-gui"/>' ${home_dir}/conf/tomcat-users.xml
}

check_java_version(){

	java_version=$(java -version 2>&1 | grep -Eo [0-9.]+_[0-9]+ | awk 'NR==1{print}')
	echo -e "${info} 当前JDK版本为${java_version}"
	if [[ $(echo ${java_version} | grep -Eo '[0-9]{1}\.[0-9]{1}') < '1.8' ]];then
		return 0
	else
		return 1
	fi
}

memory_overflow_config(){

	cat >/tmp/tomcat_jvm8<<-EOF
	JAVA_OPTS="-Xms512m
	-Xmx512m
	-Xmn192m
	-Xss512k
	-XX:SurvivorRatio=10
	-XX:MetaspaceSize=96m
	-XX:MaxMetaspaceSize=128m
	-XX:+UseConcMarkSweepGC
	-XX:+CMSScavengeBeforeRemark
	-XX:+CMSParallelRemarkEnabled
	-XX:+AggressiveOpts"
	EOF
	cat >/tmp/tomcat_jvm7<<-EOF
	JAVA_OPTS="-Xms512m
	-Xmx512m
	-Xmn192m
	-Xss512k
	-XX:SurvivorRatio=10
	-XX:PermSize=96M
	-XX:MaxPermSize=128M
	-XX:+UseConcMarkSweepGC
	-XX:+CMSScavengeBeforeRemark
	-XX:+CMSParallelRemarkEnabled
	-XX:+AggressiveOpts"
	EOF
	N=`grep -n '^# OS' ${home_dir}/bin/catalina.sh | awk -F ':' '{print $1}'`
	sed -i ''$N'i# JAVA_OPTS (Optional) Java runtime options used when any command is executed.' ${home_dir}/bin/catalina.sh
	check_java_version
	if [[ $? = '0' ]];then
		sed -i '/^# JAVA_OPTS.*/r /tmp/tomcat_jvm7' ${home_dir}/bin/catalina.sh
	else
		sed -i '/^# JAVA_OPTS.*/r /tmp/tomcat_jvm8' ${home_dir}/bin/catalina.sh
	fi
}

add_tomcat_service(){
	Type="forking"
	ExecStart="${home_dir}/bin/startup.sh"
	Environment="JAVA_HOME=$(echo $JAVA_HOME)"
	conf_system_service
	add_system_service ${service_name} ${home_dir}/init
}

tomcat_install_ctl(){
	install_version tomcat
	install_selcet
	tomcat_set
	install_dir_set
	download_unzip
	tomcat_install
	clear_install
}

mysql_install_set(){
	output_option '请选择mysql版本' 'mysql普通版 galera版(wsrep补丁)' 'branch'
	output_option '请选择安装模式' '单机单实例 单机多实例(mysqld_multi)' 'deploy_mode'
	if [[ ${deploy_mode} = '1' ]];then
		input_option '请输入MySQL端口' '3306' 'mysql_port'
	else
		input_option '请输入MySQL起始端口' '3306' 'mysql_port'
		input_option '输入本机部署实例个数' '2' 'deploy_num'
	fi
	input_option '请输入MySQL数据目录' '/data/mysql' 'data_dir'
	data_dir=${input_value}
	input_option '请输入MySQL[root]账号初始密码' '123456' 'mysql_passwd'
	mysql_passwd=${input_value}

}

mysql_install(){
	#添加mysql用户
	groupadd mysql >/dev/null 2>&1
	useradd -M -s /sbin/nologin mysql -g mysql >/dev/null 2>&1
	mv ${tar_dir}/* ${home_dir}
	#安装编译工具及库文件
	echo -e "${info} 正在安装编译工具及库文件..."
	yum install -y perl-Module-Pluggable libaio autoconf boost-program-options
	if [ $? = "0" ];then
		echo -e "${info} 编译工具及库文件安装成功."
	else
		echo -e "${error} 编译工具及库文件安装失败请检查!!!" && exit 1
	fi
		
	if [[ ${deploy_mode} = '1' ]];then
		mysql_initialization
		mysql_standard_config
		mysql_config
		add_sys_env "MYSQL_HOME=${home_dir} PATH=\${MYSQL_HOME}/bin:\$PATH"
		add_mysql_service
		mysql_first_password_set
	else
		mysql_multi_config_a
		for ((i=1;i<=${deploy_num};i++))
		do
			mysql_initialization
			mysql_multi_config_b
			mysql_config
			mysql_port=$((${mysql_port}+1))
		done
		mysql_multi_config_c
		add_sys_env "MYSQL_HOME=${home_dir} PATH=\${MYSQL_HOME}/bin:\$PATH"
		add_mysql_service
		mysql_first_password_set
	fi
}

mysql_initialization(){
	mkdir -p ${data_dir}/mysql-${mysql_port}
	mysql_data_dir=${data_dir}/mysql-${mysql_port}
	
	chown -R mysql:mysql ${home_dir}
	chown -R mysql:mysql ${mysql_data_dir}

	if [[ ${version_number} < '5.7' ]];then
		${home_dir}/scripts/mysql_install_db --user=mysql --basedir=${home_dir} --datadir=${mysql_data_dir} >/dev/null 2>&1
	else
		${home_dir}/bin/mysqld --initialize-insecure --user=mysql --basedir=${home_dir} --datadir=${mysql_data_dir} >/dev/null 2>&1
	fi
	if [ $? = "0" ]; then
		diy_echo "初始化数据库完成..." "" "${info}"
		chown -R root:root ${home_dir}
		chown -R mysql:mysql ${mysql_data_dir}
	else 
		diy_echo "初始化数据库失败..." "${red}" "${error}"
		exit 1
	fi
}

mysql_standard_config(){
	cat >${home_dir}/my.cnf<<EOF
# Example mysql config file for large systems.
#
# This is for a large system with memory of 1G-2G where the system runs mainly
# mysql.
#
# mysql programs look for option files in a set of
# locations which depend on the deployment platform.
# You can copy this option file to one of those
# locations. For information about these locations, see:
# http://dev.mysql.com/doc/mysql/en/option-files.html
#
# In this file, you can use all long options that a program supports.
# If you want to know which options a program supports, run the program
# with the "--help" option.

# The following options will be passed to all mysql clients
[client]
port		= 3306
socket	= /usr/local/mysql/data/mysql.sock
default-character-set = utf8mb4
# Here follows entries for some specific programs

# The mysql server
[mysqld]

port	= 3306
socket	= /usr/local/mysql/data/mysql.sock
basedir = /usr/local/mysql
datadir = /usr/local/mysql/data
user = mysql

character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
init_connect = 'SET NAMES utf8mb4'

#public set
server-id	= 1
back_log = 500
max_connections = 1000
max_allowed_packet = 32M
max_heap_table_size = 64M
table_open_cache = 2048
table_open_cache_instances = 4
tmp_table_size = 64M
query_cache_size = 64M
query_cache_limit = 4M
key_buffer_size = 384M
sort_buffer_size = 8M
read_buffer_size = 2M
read_rnd_buffer_size = 16M
join_buffer_size = 8M

#thread
thread_cache_size = 128

#network
skip-host-cache
skip-name-resolve

#other
lower_case_table_names = 1
skip-external-locking

#MySQL5.7
#log_timestamps = SYSTEM

# innodb set
innodb_open_files = 2048
innodb_log_file_size = 128M
innodb_buffer_pool_size = 2G
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 2
innodb_write_io_threads = 8
innodb_read_io_threads = 8

# myisam set
myisam_sort_buffer_size = 64M

# binlog set
binlog_format = mixed
expire_logs_days = 15
max_binlog_size = 512M
sync_binlog = 200
log-bin = mysql-bin
log-bin-index = mysql-bin.index
binlog-ignore-db = mysql
binlog-ignore-db = information_schema
binlog-ignore-db = performance_schema
binlog_cache_size = 4M

# relay-logbinary logging
#relay-log = relay-bin
#relay-log-index = relay-bin.index
#replicate-ignore-db = mysql
#replicate-ignore-db = information_schema
#replicate-ignore-db = performance_schema
#replicate-do-db = test

# GTID
#gtid-mode = ON
#log-slave-updates = ON
#enforce-gtid-consistency = ON
#auto-increment-increment = 2 
#auto-increment-offset = 1

# slow log
slow_query_log = 1
long_query_time = 1
#log_queries_not_using_indexes = 1

# wsrep set
#wsrep_provider = 
#wsrep_cluster_address = "gcomm://"
#wsrep_cluster_name = "mycluster"
#wsrep_node_name = "node1"
#wsrep_node_address = "192.168.71.177:4567"
#binlog_format = row
#default_storage_engine = InnoDB
#innodb_autoinc_lock_mode = 2
#bind-address = 0.0.0.0
#wsrep_sst_method = rsync
#wsrep_slave_threads = 16

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash
# Remove the next comment character if you are not familiar with SQL
default-character-set = utf8mb4

[myisamchk]
key_buffer_size = 512M
sort_buffer_size = 512M
read_buffer = 8M
write_buffer = 8M

[mysqlhotcopy]
interactive-timeout
EOF
}

mysql_multi_config_a(){
	cat >${home_dir}/my.cnf<<EOF
# Example mysql config file for large systems.
#
# This is for a large system with memory of 1G-2G where the system runs mainly
# mysql.
#
# mysql programs look for option files in a set of
# locations which depend on the deployment platform.
# You can copy this option file to one of those
# locations. For information about these locations, see:
# http://dev.mysql.com/doc/mysql/en/option-files.html
#
# In this file, you can use all long options that a program supports.
# If you want to know which options a program supports, run the program
# with the "--help" option.

# The following options will be passed to all mysql clients
[mysqld_multi] 
mysqld    = /usr/local/mysql/bin/mysqld
mysqladmin = /usr/local/mysql/bin/mysqladmin
log        = /tmp/mysql_multi.log

EOF
}

mysql_multi_config_b(){
	cat >>${home_dir}/my.cnf<<EOF
# The mysql server
[mysqld${mysql_port}]
port		= ${mysql_port}
socket	= /usr/local/mysql/data/mysql.sock
basedir = /usr/local/mysql
datadir = /usr/local/mysql/data
user = mysql

character-set-client-handshake=FALSE
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
init_connect='SET NAMES utf8mb4'

#public set
server-id	= 1
back_log = 500
max_connections = 1000
max_allowed_packet = 32M
max_heap_table_size = 64M
table_open_cache = 2048
table_open_cache_instances = 4
tmp_table_size = 64M
query_cache_size = 64M
query_cache_limit = 4M
key_buffer_size = 384M
sort_buffer_size = 8M
read_buffer_size = 2M
read_rnd_buffer_size = 16M
join_buffer_size = 8M

#thread
thread_cache_size = 64

#network
skip-host-cache
skip-name-resolve

#other
lower_case_table_names = 1
skip-external-locking

#MySQL5.7
#log_timestamps = SYSTEM

# innodb set
innodb_open_files = 2048
innodb_log_file_size = 128M
innodb_buffer_pool_size = 2G
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 2
innodb_write_io_threads = 8
innodb_read_io_threads = 8

# myisam set
myisam_sort_buffer_size = 64M

# binlog set
binlog_format = mixed
expire_logs_days = 15
sync_binlog = 200
log-bin = mysql-bin
log-bin-index = mysql-bin.index
binlog-ignore-db = mysql
binlog-ignore-db = information_schema
binlog-ignore-db = performance_schema
binlog_cache_size = 4M

# relay-logbinary logging
#relay-log = relay-bin
#relay-log-index = relay-bin.index
#replicate-ignore-db = mysql
#replicate-ignore-db = information_schema
#replicate-ignore-db = performance_schema
#replicate-do-db = test

# GTID
#gtid-mode = ON
#log-slave-updates = ON
#enforce-gtid-consistency = ON
#auto-increment-increment = 2 
#auto-increment-offset = 1

# slow log
slow_query_log = 1
long_query_time = 1
#log_queries_not_using_indexes = 1

# wsrep set
#wsrep_provider = 
#wsrep_cluster_address = "gcomm://"
#wsrep_cluster_name = "mycluster"
#wsrep_node_name = "node1"
#wsrep_node_address = "192.168.71.177:4567"
#binlog_format = row
#default_storage_engine = InnoDB
#innodb_autoinc_lock_mode = 2
#bind-address = 0.0.0.0
#wsrep_sst_method = rsync
#wsrep_slave_threads = 16
EOF
}

mysql_multi_config_c(){
	cat >>${home_dir}/my.cnf<<EOF
[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash
# Remove the next comment character if you are not familiar with SQL
default-character-set = utf8mb4

[myisamchk]
key_buffer_size = 512M
sort_buffer_size = 512M
read_buffer = 8M
write_buffer = 8M

[mysqlhotcopy]
interactive-timeout
EOF
}

mysql_config(){

	#通用配置
	sed -i 's#socket	= /usr/local/mysql/data#socket		= '${mysql_data_dir}'#' ${home_dir}/my.cnf
	sed -i 's#basedir = /usr/local/mysql#basedir = '${home_dir}'#' ${home_dir}/my.cnf
	sed -i 's#datadir = /usr/local/mysql/data#datadir = '${mysql_data_dir}'#' ${home_dir}/my.cnf
	#版本区别配置
	if [[ ${version_number} > '5.6' ]];then
		sed -i 's/#log_timestamps = SYSTEM/log_timestamps = SYSTEM/' ${home_dir}/my.cnf
	fi
	#部署模式区别配置
	if [[ ${deploy_mode} = '1' ]];then
		sed -i 's#^port.*#port		= '${mysql_port}'#' ${home_dir}/my.cnf
	else
		sed -i 's#^mysqld    = /usr/local/mysql/bin/mysqld#mysqld    = '${home_dir}'/bin/mysqld#' ${home_dir}/my.cnf
		sed -i 's#^mysqladmin = /usr/local/mysql/bin/mysqladmin#mysqladmin = '${home_dir}'/bin/mysqladmin#' ${home_dir}/my.cnf
	fi
}

add_mysql_service(){

	if [[ ${deploy_mode} = '1' ]];then
		User="mysql"
		ExecStart="${home_dir}/bin/mysqld_safe --defaults-file=${home_dir}/my.cnf"
		conf_system_service
		add_system_service mysqld ${home_dir}/init y
	elif [[ ${deploy_mode} = '2' ]];then
		if [[ ${os_release} > 6 ]];then
			ExecStart="${home_dir}/bin/mysqld_multi --defaults-file=${home_dir}/my.cnf --log=/tmp/mysql_multi.log start %i"
			ExecStop="${home_dir}/bin/mysqld_multi --defaults-file=${home_dir}/my.cnf stop %i"
			conf_system_service
			add_system_service mysqld@ ${home_dir}/init y
		else
			ExecStart="${home_dir}/bin/mysqld_multi --defaults-file=${home_dir}/my.cnf start \$2"
			ExecStop="${home_dir}/bin/mysqld_multi --defaults-file=${home_dir}/my.cnf stop \$2"
			conf_system_service
			add_system_service mysqld_multi ${home_dir}/init y
		fi
	fi

}

mysql_first_password_set(){
	sleep 5
	if [[ ${version_number} < '5.7' ]];then
		${home_dir}/bin/mysql -uroot -S${mysql_data_dir}/mysql.sock -e "use mysql;update user set password=PASSWORD("\'${mysql_passwd}\'") where user='root';\nflush privileges;"
		${home_dir}/bin/mysql -uroot -S${mysql_data_dir}/mysql.sock -p${mysql_passwd}<<-EOF
		delete from mysql.user where not (user='root');
		DELETE FROM mysql.user where user='';
		flush privileges;
		EOF
	else
		${home_dir}/bin/mysql -uroot -S${mysql_data_dir}/mysql.sock -e "use mysql;update user set authentication_string = password("\'${mysql_passwd}\'"), password_expired = 'N', password_last_changed = now() where user = 'root';\nflush privileges;"
		${home_dir}/bin/mysql -uroot -S${mysql_data_dir}/mysql.sock -p${mysql_passwd}<<-EOF
		delete from mysql.user where not (user='root');
		DELETE FROM mysql.user where user='';
		flush privileges;
		EOF
	fi
	if [[ $? = '0' ]];then
		diy_echo "设置密码成功..." "" "${info}"
	else
		diy_echo "设置密码失败..." "${red}" "${error}"
	fi
}

mysql_install_ctl(){
	install_version mysql
	install_selcet
	mysql_install_set
	install_dir_set 
	download_unzip 
	mysql_install
	clear_install
}

mysql_user_passwd(){
	
	echo -e "${info} 请输入要连接的MySQL的IP:"
	stty erase '^H' && read -p "(默认localhost):" mysql_ip
	[[ -z ${mysql_ip} ]] && mysql_ip='localhost'
	
	echo -e "${info} 请输入要连接的MySQL账号:"
	stty erase '^H' && read -p "(默认root):" mysql_user
	if [[ -z ${mysql_user} ]];then
		mysql_user='root'
	elif [[ ! -z ${mysql_user} && ${mysql_user} = 'ROOT' ]];then
		mysql_user='root'
	fi
	echo -e "${info} 请输入要连接的MySQL密码:"
	stty erase '^H' && read -s mysql_passwd
	[[ -z ${mysql_passwd} ]] && echo -e "${error} 密码不能为空!请重新设置!" && mysql_user_passwd
		
	echo -e "${info} 请输入要连接的MySQL端口:"
	stty erase '^H' && read -p "(默认3306):" mysql_port
	[[ -z ${mysql_port} ]] && mysql_port='3306'	
}

mysql_password_check(){

	for((p=1;p<3;p++))
	do
		echo -e "${info} 正在检测MySQL密码是否正确..."
		mysql -u${mysql_user} -p${mysql_passwd} -h${mysql_ip} -P${mysql_port} -e 'quit' > /dev/null 2>1&
		if [ $? = 0 ];then
			echo -e "${info} 登陆成功."
			return 0
			break 
		else
			echo -e "${error} 登陆失败!请重试!"
			mysql_user_passwd
		fi
	done
	echo -e "${error} 登陆失败次数超过三次请先核实MySQL信息!!!"
	exit 1
}

crond_service_check(){
echo -e "${info} 正在检测crond服务是否启动..."
crond=`rpm -qa|grep cron | awk 'END{print NR}'`
[ ${crond} -lt 3 ] && echo -e "${error} 好像crond服务没有被安装!!!尝试安装中..." && yum -y install vixie-cron && echo -e "${info} crond服务安装成功."
if [[ "${os_name}" = "Centos" && "${os_release}" -lt 7 ]]; then
	crond_service=`chkconfig --list | grep -c crond`
	if [  ${crond_service} = 0 ];then
		chkconfig --add crond
		chkconfig --level 345 crond on
		echo -e "${info} 正在启动crond服务..." && service crond start
		[ $? = "0" ] && echo -e "${info} crond服务成功启动..." && return 0
	elif [ ${crond_service} = 1 ];then
		service crond status > /dev/null
		if [ $? = "0" ];then
			echo -e "${info} crond服务已经启动..." && return 0	
		else
			echo -e "${info} 正在启动crond服务..." && service crond start
			[ $? = "0" ] && echo -e "${info} crond服务成功启动..." && return 0
		fi		
	else 
		echo -e "${error} 由于未知原因crond服务没有启动!!!"
		exit 1
	fi
elif [[ "${os_name}" = "Centos" && "${os_release}" -ge 7 ]]; then
	crond_service=`ls /etc/systemd/system/multi-user.target.wants | grep -c crond.service`
	if [ ${crond_service} = 0 ];then
		systemctl enable crond
		systemctl start crond
		[ $? = "0" ] && echo -e "${info} crond服务成功启动..." && return 0
	elif [ ${crond_service} = 1 ];then
		systemctl status crond > /dev/null
		if [ $? = "0" ];then
			echo -e "${info} crond服务已经启动..." && return 0
		else
			echo -e "${info} 正在启动crond服务..." && systemctl start crond
			[ $? = "0" ] && echo -e "${info} crond服务成功启动..." && return 0
		fi
	else 
		echo -e "${error} 由于未知原因crond服务没有启动!!!"
		exit 1
	fi
fi
}

reset_mysql_passwd(){

	mysql_mysqld_safe_dir=`find / -name mysqld_safe` && mysql_bin_dir=${mysql_mysqld_safe_dir%/*}
	[ -z ${mysql_bin_dir} ] && echo -e "${error} 似乎MySQL文件有缺失,请检查!" && exit
	mysql_version=`${mysql_bin_dir}/mysql -V | awk '{print $5}' | tr -d ","`
	read -p "输入MySQL新密码:" mysql_new_password
	[ -z ${mysql_new_password} ] && echo -e "${error} 密码不能为空请重新设置!" && reset_mysql_passwd
	echo -e "${info} 正在停止MySQL服务..."
	/etc/init.d/mysqld stop >/dev/null 2>&1
	if [ $? = "0" ];then
		pkill mysql
	fi
	echo -e "${info} 正在以安全模式启动MySQL服务..."
	${mysql_bin_dir}/mysqld_safe --skip-grant-tables >/dev/null 2>&1 &
	sleep 5
	if [ $? = "0" ];then
		if echo "${mysql_version}" | grep -Eqi '^5.7.'; then
			${mysql_bin_dir}/mysql -u root mysql << EOF
		update user set authentication_string = Password('${mysql_new_password}') where User = 'root';
EOF
		else
			${mysql_bin_dir}/mysql -u root mysql << EOF
		update user set password = Password('${mysql_new_password}') where User = 'root';
EOF
		fi
		if [ $? = "0" ]; then
			echo -e "${info} 重置密码成功,正在退出安全模式..."
			killall mysqld
			sleep 5
			/etc/init.d/mysqld start >/dev/null 2>&1
			echo -e "${info} MySQL启动成功."
		else
			echo -e "${error} 重置密码失败,正在退出安全模式..."
		fi
	else
		echo -e "${error} 安全模式启动失败,正在退出..."
		killall mysqld
	fi
}

mongodb_install_set(){
	if [[ ${os_bit} = '32' ]];then
		diy_echo "该版本不支持32位系统" "${red}" "${error}"
		exit 1
	fi
	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'
	input_option '请输入本机部署个数' '1' 'deploy_num'
	input_option '请输入起始端口号' '27017' 'mongodb_port'
	input_option '请输入数据存储路径' '/data' 'mongodb_data_dir'
	mongodb_data_dir=${input_value}
}

mongodb_install(){
	mv ${tar_dir}/* ${home_dir}
	mkdir -p ${home_dir}/etc
	mkdir -p ${mongodb_data_dir}
	mongodb_config
	add_mongodb_service
}

mongodb_config(){
	conf_dir=${home_dir}/etc
	cat >${conf_dir}/mongodb.conf<<-EOF
	#端口号
	port = 27017
	bind_ip=0.0.0.0
	#数据目录
	dbpath=
	#日志目录
	logpath=
	fork = true
	#日志输出方式
	logappend = true
	#开启认证
	#auth = true
	EOF
	sed -i "s#port.*#port = ${mongodb_port}#" ${conf_dir}/mongodb.conf
	sed -i "s#dbpath.*#dbpath = ${mongodb_data_dir}#" ${conf_dir}/mongodb.conf
	sed -i "s#logpath.*#logpath = ${home_dir}/logs/mongodb.log#" ${conf_dir}/mongodb.conf
	add_sys_env "PATH=\${home_dir}/bin:\$PATH"
	add_log_cut mongodb ${home_dir}/logs/mongodb.log
}

add_mongodb_service(){
	ExecStart="${home_dir}/bin/mongod -f ${home_dir}/etc/mongodb.conf"
	ExecStop="${home_dir}/bin/mongod -f ${home_dir}/etc/mongodb.conf"
	conf_system_service
	add_sys_env "PATH=${home_dir}/bin:\$PATH"
	add_system_service mongodb ${home_dir}/mongodb_init
}

mongodb_inistall_ctl(){
	install_version mongodb
	install_selcet
	mongodb_install_set
	install_dir_set
	download_unzip
	mongodb_install
	clear_install
}

nginx_install_set(){
	input_option '是否添加额外模块' 'n' 'add'
	add=${input_value}
	yes_or_no ${add}
	if [[ $? = '0' ]];then
		output_option '选择要添加的模块' 'fastdfs-nginx-module' 'add_module'
		add_module_value=${output_value}
	fi
}

nginx_install(){

	#安装编译工具及库文件
	echo -e "${info} 正在安装编译工具及库文件..."
	yum -y install make zlib zlib-devel gcc-c++ libtool  openssl openssl-devel pcre pcre-devel
	if [ $? = "0" ];then
		echo -e "${info} 编译工具及库文件安装成功."
	else
		echo -e "${error} 编译工具及库文件安装失败请检查!!!" && exit 1
	fi
	useradd -M -s /sbin/nologin nginx
}

nginx_compile(){
	cd ${tar_dir}
	if [[ x${add_module} = 'x' ]];then
		./configure --prefix=${home_dir} --group=nginx --user=nginx --with-http_stub_status_module --with-http_ssl_module --with-http_gzip_static_module --with-pcre --with-stream --with-stream_ssl_module
	else
		wget https://codeload.github.com/happyfish100/fastdfs-nginx-module/zip/master -O fastdfs-nginx-module-master.zip && unzip -o fastdfs-nginx-module-master.zip
		./configure --prefix=${home_dir} --group=nginx --user=nginx --with-http_stub_status_module --with-http_ssl_module --with-http_gzip_static_module --with-pcre --with-stream --with-stream_ssl_module --add-module=${tar_dir}/${add_module_value}-master/src
		#sed -i 's///'
	fi
	make && make install
	if [ $? = "0" ];then
		echo -e "${info} nginx安装成功."
	else
		echo -e "${error} nginx安装失败!!!"
		exit 1
	fi

}

nginx_config(){
	conf_dir=${home_dir}/conf
	cat >/tmp/nginx.tmp<<EOF
    server_names_hash_bucket_size 128;
    large_client_header_buffers 4 32k;
    client_header_buffer_size 32k;
    client_max_body_size 100m;
    client_header_timeout 120s;
    client_body_timeout 120s;
	 
    proxy_buffer_size 64k;
    proxy_buffers   4 32k;
    proxy_busy_buffers_size 64k;
    proxy_connect_timeout 120s;
    proxy_send_timeout 120s;
    proxy_read_timeout 120s;
    
	server_tokens off;
    sendfile   on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 60;
     
    gzip  on;
    gzip_min_length 1k;
    gzip_buffers 4 16k;
    gzip_comp_level 3;
    gzip_http_version 1.0;
    gzip_types text/plain application/x-javascript text/css application/xml text/javascript application/x-httpd-php image/jpeg image/gif image/png;
    gzip_vary on;
    gzip_disable "MSIE [1-6]\.";
EOF
	sed -i '/logs\/access.log/,/#gzip/{//!d}' ${conf_dir}/nginx.conf
	sed -i '/#gzip/r /tmp/nginx.tmp' ${conf_dir}/nginx.conf && rm -rf /tmp/nginx.tmp
	add_log_cut nginx ${home_dir}/logs/*.log
}

add_nginx_service(){

	Type="forking"
	ExecStart="${home_dir}/sbin/nginx -c ${home_dir}/conf/nginx.conf"
	ExecReload="${home_dir}/sbin/nginx -s reload"
	ExecStop="${home_dir}/sbin/nginx -s stop"
	conf_system_service
	add_system_service nginx ${home_dir}/init
}

nginx_install_ctl(){

	install_version nginx
	install_selcet
	nginx_install_set
	install_dir_set
	download_unzip
	nginx_install
	nginx_compile
	nginx_config
	add_nginx_service
	clear_install
	
}

php_install_set(){
	output_option '请选择安装模式' 'PHP作为httpd模块 FastCGI(php-fpm)模式 PHP同时开启两个种模式' 'php_mode'
	input_option '是否添加额外模块' 'n' 'add'
	add=${input_value}
	yes_or_no ${add}
	if [[ $? = '0' ]];then
		output_option '请选择需要安装的php模块(可多选)' 'redis memcached' 'php_modules'
		php_modules=(${output_value[@]})
	fi
		
	[ ${php_mode} = 1 ] && fpm="" && apxs2="--with-apxs2=`find / -name apxs`"
	[ ${php_mode} = 2 ] && fpm="--enable-fpm" && apxs2=""
	[ ${php_mode} = 3 ] && fpm="--enable-fpm" && apxs2="--with-apxs2=`which apxs`"
	[[ ${version_number} < '7.0' ]] && mysql="--with-mysql=mysqlnd"
	[[ ${version_number} = '7.0' || ${version_number} > '7.0' ]] && mysql=""
}

php_install_depend(){
	#安装编译工具及库文件
	diy_echo "正在安装编译工具及库文件..." "" "${info}"
	system_optimize_yum
	[[ ${os_release} < "7" ]] && [[ ${php_mode} = 1 || ${php_mode} = 3 ]] && yum -y install  httpd httpd-devel mod_proxy_fcgi
	[[ ${os_release} > "6" ]] && [[ ${php_mode} = 1 || ${php_mode} = 3 ]] && yum -y install httpd httpd-devel
	yum  -y install gcc gcc-c++ libxml2 libxml2-devel bzip2 bzip2-devel libmcrypt libmcrypt-devel openssl openssl-devel libcurl-devel libjpeg-devel libpng-devel freetype-devel readline readline-devel libxslt-devel perl perl-devel psmisc.x86_64 recode recode-devel libtidy libtidy-devel

}

php_install(){

	cd ${tar_dir}
	conf_dir=${home_dir}/etc
	extra_conf_dir=${home_dir}/etc.d
	mkdir -p ${home_dir}/{etc,etc.d}
	#必要函数库
	wget https://mirrors.huaweicloud.com/gnu/libiconv/libiconv-1.15.tar.gz && tar zxf libiconv-1.15.tar.gz && cd libiconv-1.15 && ./configure --prefix=/usr && make && make install && cd ..
	if [ $? = "0" ];then
		diy_echo "libiconv库编译及编译安装成功..." "" "${info}"
	else
		diy_echo "libiconv库编译及编译安装失败..." "${red}" "${error}"
		exit 1
	fi
	php_compile
	php_config
	if [[ ${php_modules[@]} != '' ]];then
		php_modules_install
	fi
}

php_compile(){

	./configure --prefix=${home_dir} --with-config-file-path=${home_dir}/etc --with-config-file-scan-dir=${home_dir}/etc.d ${fpm} ${apxs2} ${mysql} --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-mhash --with-openssl --with-zlib --with-bz2 --with-curl --with-libxml-dir --with-gd --with-jpeg-dir --with-png-dir --with-zlib --enable-mbstring --with-mcrypt --enable-sockets --with-iconv-dir --with-xsl --enable-zip --with-pcre-dir --with-pear --enable-session  --enable-gd-native-ttf --enable-xml --with-freetype-dir --enable-inline-optimization --enable-shared --enable-bcmath --enable-sysvmsg --enable-sysvsem --enable-sysvshm --enable-mbregex --enable-pcntl --with-xmlrpc --with-gettext --enable-exif --with-readline --with-recode --with-tidy --enable-soap
	make && make install
	if [ $? = "0" ];then
		diy_echo "php编译完成..." "" "${info}"
	else
		diy_echo "php编译失败..." "${red}" "${error}"
		exit 1
	fi

}

php_modules_install(){
	php_redis='https://github.com/phpredis/phpredis'
	php_memcached='https://github.com/php-memcached-dev/php-memcached'
	
	if [[ ${php_modules[@]} =~ 'redis' ]];then

		[[ ${version_number} > '5.6' ]] && wget ${php_redis}/archive/master.tar.gz -O  phpredis-master.tar.gz && tar zxf phpredis-master.tar.gz && cd phpredis-master
		[[ ${version_number} < '7.0' ]] && wget ${php_redis}/archive/4.3.0.tar.gz -O  phpredis-4.3.0.tar.gz && tar zxf phpredis-4.3.0.tar.gz && cd phpredis-4.3.0
		${home_dir}/bin/phpize
		./configure --with-php-config=${home_dir}/bin/php-config && make && make install && cd ..
		if [[ $? = '0' ]];then
			cat > ${extra_conf_dir}/redis.ini<<-EOF
			[redis]
			extension = redis.so
			EOF
		else
			diy_echo "redis模块编译失败" "${red}" "${error}"
			exit
		fi
	fi

	if [[ ${php_modules[@]} =~ 'memcached' ]];then
		#安装依赖的库和头文件
		yum install -y libmemcached libmemcached-devel
		[[ ${version_number} > '5.6' ]] && wget ${php_memcached}/archive/master.tar.gz -O  php-memcached-master.tar.gz && tar zxf php-memcached-master.tar.gz && cd php-memcached-master
		[[ ${version_number} < '7.0' ]] && wget ${php_memcached}/archive/2.2.0.tar.gz -O  php-memcached-2.2.0.tar.gz && tar zxf php-memcached-2.2.0.tar.gz && cd php-memcached-2.2.0
		${home_dir}/bin/phpize
		./configure --with-php-config=${home_dir}/bin/php-config && make && make install && cd ..
		if [[ $? = '0' ]];then
			cat > ${extra_conf_dir}/memcached.ini<<-EOF
			[memcached]
			extension = memcached.so
			EOF
		else
			diy_echo "memcached模块编译失败" "${red}" "${error}"
			exit
		fi
	fi
}

php_config(){

	cp ./php.ini-production ${conf_dir}/php.ini
	#最大上传相关配置
	sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' ${conf_dir}/php.ini
	sed -i 's/post_max_size =.*/post_max_size = 60M/g' ${conf_dir}/php.ini
	sed -i 's/memory_limit =.*/memory_limit = 128M/g' ${conf_dir}/php.ini
	sed -i 's/max_execution_time =.*/max_execution_time = 300/g' ${conf_dir}/php.ini
	sed -i 's/max_input_time =.*/max_input_time = 300/g' ${conf_dir}/php.ini
	#其它
	sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${conf_dir}/php.ini
  
	if [[ ${php_mode} = 2 || ${php_mode} = 3 ]];then
		if [[ ${version_number} > '5.6' ]];then
			cp ${conf_dir}/php-fpm.d/www.conf.default ${conf_dir}/php-fpm.d/www.conf
			cp ${conf_dir}/php-fpm.conf.default ${conf_dir}/php-fpm.conf
			sed -i 's/pm.max_children =.*/pm.max_children = 10/' ${conf_dir}/php-fpm.d/www.conf
			sed -i 's/pm.start_servers =.*/pm.start_servers = 4/' ${conf_dir}/php-fpm.d/www.conf
			sed -i 's/pm.min_spare_servers =.*/pm.min_spare_servers = 2/' ${conf_dir}/php-fpm.d/www.conf
			sed -i 's/pm.max_spare_servers =.*/pm.max_spare_servers = 6/' ${conf_dir}/php-fpm.d/www.conf
			sed -i 's/;pm.max_requests =.*/pm.max_requests = 1024/' ${conf_dir}/php-fpm.d/www.conf
			sed -i 's#;pm.status_path =.*#;pm.status_path = /php_status#' ${conf_dir}/php-fpm.d/www.conf
			sed -i 's#;ping.path =.*#ping.path = /ping#' ${conf_dir}/php-fpm.d/www.conf
		else
			cp ${conf_dir}/php-fpm.conf.default ${conf_dir}/php-fpm.conf
			sed -i 's/pm.max_children =.*/pm.max_children = 10/' ${conf_dir}/php-fpm.conf
			sed -i 's/pm.start_servers =.*/pm.start_servers = 4/' ${conf_dir}/php-fpm.conf
			sed -i 's/pm.min_spare_servers =.*/pm.min_spare_servers = 2/' ${conf_dir}/php-fpm.conf
			sed -i 's/pm.max_spare_servers =.*/pm.max_spare_servers = 6/' ${conf_dir}/php-fpm.conf
			sed -i 's/;pm.max_requests =.*/pm.max_requests = 1024/' ${conf_dir}/php-fpm.conf
			sed -i 's#;pm.status_path =.*#;pm.status_path = /php_status#' ${conf_dir}/php-fpm.conf
			sed -i 's#;ping.path =.*#ping.path = /ping#' ${conf_dir}/php-fpm.conf
		fi
		if [[ ${os_release} < '7' ]];then
			cp ./sapi/fpm/init.d.php-fpm ${home_dir}/php_fpm_init
		else
			sed -i 's#${prefix}#'${home_dir}'#' ./sapi/fpm/php-fpm.service
			sed -i 's#${exec_prefix}#'${home_dir}'#' ./sapi/fpm/php-fpm.service
			cp ./sapi/fpm/php-fpm.service ${home_dir}/php_fpm_init
		fi
	fi
	add_system_service php-fpm ${home_dir}/php_fpm_init
	add_sys_env "PATH=${home_dir}/bin:\$PATH PATH=${home_dir}/sbin:\$PATH"
}

php_install_ctl(){

	install_version php
	install_selcet
	php_install_set
	install_dir_set
	download_unzip
	php_install_depend
	php_install
	clear_install
	
}

redis_install_set(){

	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'
	if [[ ${deploy_mode} = '1' ]];then
		input_option '请设置端口号' '6379' 'redis_port'
		input_option '请设置redis密码' 'passw0ord' 'redis_password'
		redis_password=${input_value}
	else
		output_option '请选择集群模式' '多主多从(集群模式) 一主多从(哨兵模式)' 'cluster_mode'
	fi
		
	if [[ ${cluster_mode} = '1' ]];then
		input_option '输入本机部署个数' '2' 'deploy_num'
		only_allow_numbers ${deploy_num}
		if [[ $? = 1 ]];then
			echo -e "${error} 输入错误请重新设置"
			redis_install_set
		fi
		input_option '输入起始端口号' '7001' 'redis_port'
		input_option '请设置redis密码' 'passw0ord' 'redis_password'
		redis_password=${input_value}
	fi

	if [[ ${cluster_mode} = '2' ]];then
		input_option '输入本机部署个数' '1' 'deploy_num'
		only_allow_numbers ${deploy_num}
		if [[ $? = 1 ]];then
			echo -e "${error} 输入错误请重新设置"
			redis_install_set
		fi
		
		node_type_set 
		
		if [[ ${node_type} = 'm' ]];then
			echo -e "${info} 这将第一个节点配置为主节点，其余节点为从节点。"
			input_option '输入起始端口号' '7001' 'redis_port'
			input_option '请设置redis密码' 'passw0ord' 'redis_password'
			redis_password=${input_value}
		elif [[ ${node_type} = 's' ]];then
			echo -e "${info} 这将所有节点都配置从节点，密码必须和主节点一样！"
			diy_echo "输入需要同步的主节点的信息" "$plain" "$info"
			input_option '请输入主节点ip地址' '192.168.1.1' 'mast_redis_ip'
			mast_redis_ip="$input_value"
			input_option '请输入主节点端口号' '6379' 'mast_redis_port'
			input_option '请输入主节点验证密码' 'password' 'mast_redis_passwd'
			mast_redis_passwd="$input_value"
			redis_password="$input_value"
			input_option '输入起始端口号' '7001' 'redis_port'
		fi
	fi
	diy_echo '按任意键继续' '' "$info"
	read

}

redis_install(){

	echo -e "${info} 正在安装编译工具及库文件..."
	yum -y install make  gcc-c++
	if [ $? = '0' ];then
		echo -e "${info} 编译工具及库文件安装成功."
	else
		echo -e "${error} 编译工具及库文件安装失败请检查!!!" && exit 1
	fi
	if [[ ${deploy_mode} = '2' && ${cluster_mode} = '1' && ${version_number} < '5.0' ]];then
		if [[ $(which ruby 2>/dev/null)  &&  $(ruby -v | grep -oE "[0-9]{1}\.[0-9]{1}\.[0-9]{1}") > '2.2.2' ]];then
			gem install redis
		else
			diy_echo "ruby未安装或者版本低于2.2.2" "" "${error}"
			exit 1
		fi
	fi

	cd ${tar_dir}
	make && cd ${tar_dir}/src && make PREFIX=${home_dir} install
	if [ $? = '0' ];then
		echo -e "${info} Redis安装完成"
	else
		echo -e "${error} Redis编译失败!" && exit
	fi

	if [[ ${deploy_mode} = '1' ]];then
		redis_config
		add_redis_service
		add_sys_env "PATH=${home_dir}/bin:\$PATH"
	elif [ ${deploy_mode} = '2' ];then
		if [[ ${cluster_mode} = '2' && ${node_type} = 'M' ]];then
			mast_redis_port=${redis_port}
		fi
		mv ${home_dir} ${install_dir}/tmp
		for ((i=1;i<=${deploy_num};i++))
		do
			\cp -rp ${install_dir}/tmp ${install_dir}/redis-${redis_port}
			home_dir=${install_dir}/redis-${redis_port}
			redis_config
			add_redis_service
			redis_port=$((${redis_port}+1))
		done
		add_sys_env "PATH=${home_dir}/bin:\$PATH"
		redis_cluster_description
	fi
}

redis_config(){
	get_ip
	mkdir -p ${home_dir}/{logs,etc,data}
	conf_dir=${home_dir}/etc
	cp ${tar_dir}/redis.conf ${conf_dir}/redis.conf
	sed -i "s/^bind.*/bind 127.0.0.1 ${local_ip}/" ${conf_dir}/redis.conf
	sed -i 's/^port 6379/port '${redis_port}'/' ${conf_dir}/redis.conf
	sed -i 's/^daemonize no/daemonize yes/' ${conf_dir}/redis.conf
	sed -i "s#^pidfile .*#pidfile ${home_dir}/data/redis.pid#" ${conf_dir}/redis.conf
	sed -i 's#^logfile ""#logfile "'${home_dir}'/logs/redis.log"#' ${conf_dir}/redis.conf
	sed -i 's#^dir ./#dir '${home_dir}'/data#' ${conf_dir}/redis.conf
	sed -i 's/# requirepass foobared/requirepass '${redis_password}'/' ${conf_dir}/redis.conf
	sed -i 's/# maxmemory <bytes>/maxmemory 100mb/' ${conf_dir}/redis.conf
	sed -i 's/# maxmemory-policy noeviction/maxmemory-policy volatile-lru/' ${conf_dir}/redis.conf
	sed -i 's/appendonly no/appendonly yes/' ${conf_dir}/redis.conf
	
	if [ ${deploy_mode} = '1' ];then
		add_log_cut redis ${home_dir}/logs/*.log
	elif [ ${deploy_mode} = '2' ];then
		if [[ ${cluster_mode} = '1' ]];then
			mkdir -p ${install_dir}/bin
			cp ${tar_dir}/src/redis-trib.rb ${install_dir}/bin/redis-trib.rb
			sed -i 's/^# masterauth <master-password>/masterauth '${redis_password}'/' ${conf_dir}/redis.conf
			sed -i 's/# cluster-enabled yes/cluster-enabled yes/' ${conf_dir}/redis.conf
			sed -i 's/# cluster-config-file nodes-6379.conf/cluster-config-file nodes-'${redis_port}'.conf/' ${conf_dir}/redis.conf
			sed -i 's/# cluster-node-timeout 15000/cluster-node-timeout 15000/' ${conf_dir}/redis.conf
		elif [[ ${cluster_mode} = '2' ]];then
			cp ${tar_dir}/sentinel.conf ${conf_dir}/sentinel.conf
			sed -i 's/^# masterauth <master-password>/masterauth '${redis_password}'/' ${conf_dir}/redis.conf
			if [[ ${node_type} = 'M' && ${i} != '1' ]];then
				sed -i "s/^# slaveof <masterip> <masterport>/slaveof ${mast_redis_ip} ${mast_redis_port}/" ${conf_dir}/redis.conf
			elif [[  ${node_type} = 'S' ]];then
				sed -i "s/^# slaveof <masterip> <masterport>/slaveof ${mast_redis_ip} ${mast_redis_port}/" ${conf_dir}/redis.conf
			fi
			#哨兵配置文件
			sed -i "s/^# bind.*/bind 127.0.0.1 ${local_ip}/" ${conf_dir}/sentinel.conf
			sed -i "s/^port 26379/port 2${redis_port}/" ${conf_dir}/sentinel.conf
			sed -i "s#^dir /tmp#dir ${home_dir}/data\nlogfile ${home_dir}/log/sentinel.log\npidfile ${home_dir}/data/redis_sentinel.pid\ndaemonize yes#" ${conf_dir}/sentinel.conf
			sed -i "s#^sentinel monitor mymaster 127.0.0.1 6379 2#sentinel monitor mymaster ${local_ip} ${mast_redis_port} 2#" ${conf_dir}/sentinel.conf
			sed -i 's!^# sentinel auth-pass mymaster.*!sentinel auth-pass mymaster '${redis_password}'!' ${conf_dir}/sentinel.conf
		fi
		add_log_cut redis_${redis_port} ${home_dir}/logs/*.log
	fi

}

add_redis_service(){
	Type="forking"
	ExecStart="${home_dir}/bin/redis-server ${home_dir}/etc/redis.conf"
	PIDFile="${home_dir}/data/redis.pid"
	conf_system_service
	if [[ ${deploy_mode} = '1' ]];then
		add_system_service redis ${home_dir}/init
	elif [[ ${deploy_mode} = '2' ]];then
		add_system_service redis-${redis_port} ${home_dir}/init
		if [[ ${cluster_mode} = '2' ]];then
			ExecStart="${home_dir}/bin/redis-sentinel ${home_dir}/etc/sentinel"
			PIDFile="${home_dir}/data/redis_sentinel.pid"
			conf_system_service
			add_system_service redis-sentinel-2${redis_port} ${home_dir}/init
		fi
	fi
}

redis_cluster_description(){
	if [[ ${cluster_mode} = '1' ]];then
		diy_echo "现在Redis集群已经配置好了" "" "${info}"
		diy_echo "如果小于5.0版本,添加集群命令示例 ${install_dir}/bin/redis-trib.rb create --replicas 1 127.0.0.1:7001 127.0.0.1:7002 127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 127.0.0.1:7006,如果设置了集群密码还需要修改所使用ruby版本（本脚本默认使用ruby版本2.3.3）对应的client.rb文件（可通过find命令查找）,将password字段修改成对应的密码。"
		diy_echo "如果大于5.0版本,添加集群命令示例 redis-cli --cluster create 127.0.0.1:7001 127.0.0.1:7002 127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 127.0.0.1:7006 --cluster-replicas 1"
	elif [[ ${cluster_mode} = '2' ]];then
		diy_echo "现在Redis集群已经配置好了" "" "${info}"
	fi
}

redis_install_ctl(){

	install_version redis
	install_selcet
	redis_install_set
	install_dir_set redis
	download_unzip redis
	redis_install
	service_control redis
	clear_install
}

memcached_inistall_set(){

	output_option "请选择安装版本" "普通版 集成repcached补丁版" "branch"
	input_option "输入本机部署个数" "1" "deploy_num"
	input_option "输入起始memcached端口号" "11211" "memcached_port"

	if [[ ${branch} = '2' ]];then
		diy_echo "集成repcached补丁,该补丁并非官方发布,目前最新补丁兼容1.4.13" "${yellow}" "${warning}"
		input_option "输入memcached同步端口号" "11210" "syn_port"
	fi
}

memcached_install(){
	diy_echo "正在安装依赖库..." "" "${info}"
	yum -y install make  gcc-c++ libevent libevent-devel
	if [ $? = '0' ];then
		echo -e "${info} 编译工具及库文件安装成功."
	else
		echo -e "${error} 编译工具及库文件安装失败请检查!!!" && exit 1
	fi

	cd ${tar_dir}
	
	if [ ${branch} = '1' ];then
		./configure --prefix=${home_dir} && make && make install
	fi
	if [ ${branch} = '2' ];then
		repcached_url="http://mdounin.ru/files/repcached-2.3.1-1.4.13.patch.gz"
		wget ${repcached_url} && gzip -d repcached-2.3.1-1.4.13.patch.gz && patch -p1 -i ./repcached-2.3.1-1.4.13.patch
		./configure --prefix=${home_dir} --enable-replication && make && make install
	fi
	if [ $? = '0' ];then
		echo -e "${info} memcached编译完成."
	else
		echo -e "${error} memcached编译失败" && exit 1
	fi

	if [ ${deploy_num} = '1'  ];then
		memcached_config
		add_memcached_service
		add_sys_env "PATH=${home_dir}/bin:$PATH"
	fi
	if [[ ${deploy_num} > '1' ]];then
		mv ${home_dir} ${install_dir}/tmp
		for ((i=1;i<=${deploy_num};i++))
		do
			\cp -rp ${install_dir}/tmp ${install_dir}/memcached-node${i}
			home_dir=${install_dir}/memcached-node${i}
			memcached_config
			add_memcached_service
			memcached_port=$((${memcached_port}+1))
		done
		add_sys_env "PATH=${home_dir}/bin:$PATH"
	fi
		
}

memcached_config(){
	mkdir -p ${home_dir}/etc ${home_dir}/logs
	cat >${home_dir}/etc/memcached<<-EOF
	USER="root"
	PORT="11211"
	MAXCONN="1024"
	CACHESIZE="64"
	LOG="-vv >>$home_dir/logs/memcached.log 2>&1"
	OPTIONS=""
	EOF
	sed -i 's/PORT="11211"/PORT="'${memcached_port}'"/' ${home_dir}/etc/memcached
	if [[ ${branch} = '2' ]];then
		sed -i 's/OPTIONS="" /OPTIONS="-x 127.0.0.1 -X '${syn_port}'"/' ${home_dir}/etc/memcached
	fi

}

add_memcached_service(){

	EnvironmentFile="${home_dir}/etc/memcached"
	ExecStart="${home_dir}/bin/memcached -u \$USER -p \$PORT -m \$CACHESIZE -c \$MAXCONN \$LOG \$OPTIONS"
	conf_system_service
	if [[ ${deploy_num} = '1' ]];then
		add_system_service memcached "${home_dir}/init"
	else
		add_system_service memcached-node${i} "${home_dir}/init"
	fi
}

memcached_inistall_ctl(){

	install_version memcached
	install_selcet
	memcached_inistall_set
	install_dir_set
	download_unzip
	memcached_install
	service_control
	clear_install

}

clear_install(){
	if [[ -n ${install_dir} ]];then
		rm -rf ${install_dir}/${file_name}
		rm -rf ${tar_dir}
	fi
}

ssh_block_(){
if [ ${run_mode} = "1" ];then
	echo "#!/bin/bash
#description: ssh_block demo
#chkconfig: 2345 88 77
service_name=\"ssh-block\"
pid=\`ps aux | grep \${service_name} | grep -v grep | awk '{print \$2}'\`

# start
start(){
if [ -z \${pid} ];then
	echo \"sshblock启动完成.\"
	nohup \${service_name} > /dev/null 2>&1 &
else
	echo \"sshblock已经启动\"	
fi
}
#stop
stop(){
if [ -z \${pid} ];then
	echo \"sshblock没有启动.\"
else	
	kill -9 \${pid}
	echo \"sshblock停止成功.\"
fi
}
#restart
restart(){
stop
start
}
usage(){
echo \"Usage:{start|stop|restart|status}\"
}
status(){
if [ -z \${pid} ];then
	echo \"sshblock没有启动.\"
else	
	echo \"sshblock已经启动\"
fi
}
case \$1 in
start)
        start
        ;;
stop)
        stop
        ;;
restart)
        restart
        ;;
status)
        status
        ;;
*)
        usage
        ;;
esac
">/etc/init.d/sshblock && chmod +x /etc/init.d/sshblock && chkconfig --add sshblock && echo -e "${info} sshblock启动成功." && echo -e "${info} 服务sshblock添加自启动成功,日志文件/var/log/ssh_block.log.
使用命令:
${yellow}service sshblock start | stop | restart | status${plain}"
elif [ ${run_mode} = "2" ];then
	crond_service_check
	echo '
*/30 * * * * root sh /usr/bin/ssh-block.sh
'>>/etc/crontab && echo -e "${info} 计划任务添加成功默认每半小时执行一次
脚本文件/usr/bin/ssh-block.sh,日志文件/var/log/ssh_block.log."
fi
}

ftp_install_set(){
	input_option '是否快速配置vsftp服务' 'y' 'vsftp'
	vsftp=${input_value}
	yes_or_no ${vsftp}
	if [[ $? = 1 ]];then
		diy_echo "已经取消安装.." "${yellow}" "${warning}" && exit 1
	fi
	if [[ -n `ps aux | grep vsftp | grep -v grep` || -d /etc/vsftpd ]];then
		diy_echo "vsftp正在运行中,或者已经安装vsftp!!" "${yellow}" "${warning}"
		input_option '确定要重新配置vsftp吗?' 'y' 'continue'
		continue=${input_value}
		yes_or_no ${continue}
		if [[ $? = 1 ]];then
			diy_echo "已经取消安装.." "${yellow}" "${warning}" && exit 1
		fi
	fi
	input_option '设置ftp默认文件夹' '/data/ftp' 'ftp_dir'
	ftp_dir=${input_value[@]}

	if [[ ! -d ${ftp_dir} ]];then
		mkdir -p ${ftp_dir}  
	fi
	diy_echo "正在配置VSFTP用户,有管理员和普通用户两种角色,管理员有完全权限,普通用户只有上传和下载的权限." "" "${info}"
	input_option '输入管理员用户名' 'admin' 'manager'
	manager=${input_value[@]}
	input_option '输入管理员密码' 'admin' 'manager_passwd'
	manager_passwd=${input_value[@]}
	input_option '输入普通用户用户名' 'user' 'user'
	user=${input_value[@]}
	input_option '输入普通用户密码' 'user' 'user_passwd'
	user_passwd=${input_value[@]}
}

ftp_install(){
	diy_echo "正在安装db包..." "" "${info}"
	if [[ ${os_release} < '7' ]];then
		yum install -y db4-utils
	else
		yum install -y libdb-utils
	fi
	yum install -y vsftpd

}

ftp_config(){
	diy_echo "正在配置vsftp..." "" "${info}"
	id ftp > /dev/null 2>&1
	if [[ $? = '1' ]];then
		useradd -s /sbin/nologin ftp >/dev/null
		usermod -G ftp -d /var/ftp -s /sbin/nologin
	fi
	mkdir -p /etc/vsftpd/vsftpd.conf.d
	cat >/etc/vsftpd/vftpusers<<-EOF
	${manager}
	${manager_passwd}
	${user}
	${user_passwd}
	EOF

	chown -R ftp.ftp ${ftp_dir}
	db_load -T -t hash -f /etc/vsftpd/vftpusers /etc/vsftpd/vftpusers.db

	cat >/etc/vsftpd/vsftpd.conf<<-EOF
	# Example config file /etc/vsftpd/vsftpd.conf
	#
	# The default compiled in settings are fairly paranoid. This sample file
	# loosens things up a bit, to make the ftp daemon more usable.
	# Please see vsftpd.conf.5 for all compiled in defaults.
	#
	# READ THIS: This example file is NOT an exhaustive list of vsftpd options.
	# Please read the vsftpd.conf.5 manual page to get a full idea of vsftpd's
	# capabilities.

	#禁止匿名登陆
	anonymous_enable=NO
	anon_root=${ftp_dir}
	anon_umask=022
	#普通用户只有上传下载权限
	write_enable=YES
	virtual_use_local_privs=NO
	anon_world_readable_only=NO
	anon_upload_enable=YES
	anon_mkdir_write_enable=YES
	local_enable=YES
	#指定ftp路径
	local_root=${ftp_dir}

	local_umask=022
	connect_from_port_20=YES
	allow_writeable_chroot=YES
	reverse_lookup_enable=NO
	xferlog_enable=YES


	#开启ASCII模式传输数据
	ascii_upload_enable=YES
	ascii_download_enable=YES

	ftpd_banner=Welcome to blah FTP service.
	listen=YES
	userlist_enable=YES
	tcp_wrappers=YES

	#开启虚拟账号
	guest_enable=YES
	guest_username=ftp
	pam_service_name=vsftpd.vuser
	user_config_dir=/etc/vsftpd/vsftpd.conf.d

	#开启被动模式
	pasv_enable=YES
	pasv_min_port=40000
	pasv_max_port=40100
	EOF

	cat >/etc/vsftpd/vsftpd.conf.d/${manager}<<-EOF
	anon_umask=022
	write_enable=YES
	virtual_use_local_privs=NO
	anon_world_readable_only=NO
	anon_upload_enable=YES
	anon_mkdir_write_enable=YES
	anon_other_write_enable=YES
	EOF

	cat >/etc/pam.d/vsftpd.vuser<<-EOF
	auth required pam_userdb.so db=/etc/vsftpd/vftpusers
	account required pam_userdb.so db=/etc/vsftpd/vftpusers
	EOF

}

ftp_install_ctl(){
	ftp_install_set
	ftp_install
	ftp_config
	service_control vsftpd.service
}

minio_install_set(){
	output_option "请选择安装模式" "单机模式 集群模式" "deploy_mode"
	input_option "请输入minio端口" "9000" "minio_port"
	input_option "请输入minio存储路径" "/data/minio" "data_dir"
	data_dir=${input_value}
	input_option "请输入minio账号key(>=3位)" "minio" "minio_access"
	minio_access=${input_value}
	input_option "请输入minio认证key(8-40位)" "12345678" "minio_secret"
	minio_secret=${input_value}
}

minio_config(){
	mkdir -p ${home_dir}/{bin,etc}
	mkdir -p ${data_dir}
	mv ${install_dir}/minio-release ${home_dir}/bin/minio
	chmod +x ${home_dir}/bin/minio
	cat >${home_dir}/etc/minio<<-EOF
	MINIO_ACCESS_KEY=${minio_access}
	MINIO_SECRET_KEY=${minio_secret}
	MINIO_VOLUMES=${data_dir}
	MINIO_OPTS="-C ${home_dir}/etc --address :${minio_port}"
	EOF
	add_sys_env "PATH=${home_dir}/bin:\$PATH"
}

add_minio_service(){
	EnvironmentFile="${home_dir}/etc/minio"
	WorkingDirectory="${home_dir}"
	ExecStart="${home_dir}/bin/minio server \$MINIO_OPTS \$MINIO_VOLUMES"
	#ARGS="&"
	conf_system_service
	add_system_service minio ${home_dir}/init
}

minio_install_ctl(){
	install_selcet
	minio_install_set
	install_dir_set minio
	download_unzip
	minio_config
	add_minio_service
	service_control minio
}

fastdfs_install_set(){
	output_option '安装模式' '单机 集群' 'deploy_mode'
	output_option '安装的模块' 'tracker storage' 'install_module'
	input_option '请输入文件存储路径' '/data/fdfs' 'file_dir'
	file_dir=${input_value}
	input_option '请输入tracker端口' '22122' 'tracker_port'
	input_option '请输入storage端口' '23000' 'storage_port'

}

fastdfs_install(){
	yum install gcc -y
	cd ${tar_dir}
	diy_echo "正在安装相关依赖..." "" "${info}"
	wget https://codeload.github.com/happyfish100/libfastcommon/tar.gz/master -O libfastcommon-master.tar.gz && tar -zxf libfastcommon-master.tar.gz
	cd libfastcommon-master
	#libfastcommon安装目录配置
	sed -i "/^TARGET_PREFIX=$DESTDIR/i\DESTDIR=${home_dir}" ./make.sh
	sed -i 's#TARGET_PREFIX=.*#TARGET_PREFIX=$DESTDIR#' ./make.sh
	./make.sh  && ./make.sh install
	if [[ $? = '0' ]];then
		diy_echo "libfastcommon安装完成." "" "${info}"
	else
		diy_echo "libfastcommon安装失败." "${yellow}" "${error}"
		exit
	fi
	ln -sfn ${home_dir}/include/fastcommon /usr/include
	ln -sfn ${home_dir}/lib64/libfastcommon.so /usr/lib/libfastcommon.so
	ln -sfn ${home_dir}/lib64/libfastcommon.so /usr/lib64/libfastcommon.so
	#fastdfs安装目录配置
	cd ${tar_dir}
	sed -i "/^TARGET_PREFIX=$DESTDIR/i\DESTDIR=${home_dir}" ./make.sh
	sed -i 's#TARGET_PREFIX=.*#TARGET_PREFIX=$DESTDIR#' ./make.sh
	sed -i 's#TARGET_CONF_PATH=.*#TARGET_CONF_PATH=$DESTDIR/etc#' ./make.sh
	sed -i 's#TARGET_INIT_PATH=.*#TARGET_INIT_PATH=$DESTDIR/etc/init.d#' ./make.sh

	diy_echo "正在安装fastdfs服务..." "" "${info}"
		./make.sh && ./make.sh install
	if [[ $? = '0' ]];then
		diy_echo "fastdfs安装完成." "" "${info}"
	else
		diy_echo "fastdfs安装失败." "${yellow}" "${error}"
		exit
	fi
	ln -sfn ${home_dir}/include/fastdfs /usr/include
	ln -sfn ${home_dir}/lib64/libfdfsclient.so /usr/lib/libfdfsclient.so
	ln -sfn ${home_dir}/lib64/libfdfsclient.so /usr/lib64/libfdfsclient.so

}

fastdfs_config(){
	mkdir -p ${file_dir}
	cp ${home_dir}/etc/tracker.conf.sample ${home_dir}/etc/tracker.conf
	cp ${home_dir}/etc/storage.conf.sample ${home_dir}/etc/storage.conf
	cp ${home_dir}/etc/client.conf.sample ${home_dir}/etc/client.conf
	get_ip
	sed -i "s#base_path=.*#base_path=${file_dir}#" ${home_dir}/etc/client.conf
	sed -i "s#tracker_server=.*#tracker_server=${local_ip}:${tracker_port}#" ${home_dir}/etc/client.conf

	sed -i "s#port=23000#port=${storage_port}#" ${home_dir}/etc/storage.conf
	sed -i "s#base_path=.*#base_path=${file_dir}#" ${home_dir}/etc/storage.conf
	sed -i "s#store_path0=.*#store_path0=${file_dir}#" ${home_dir}/etc/storage.conf
	sed -i "s#tracker_server=.*#tracker_server=${local_ip}:${tracker_port}#" ${home_dir}/etc/storage.conf

	sed -i "s#port=22122#port=${tracker_port}#" ${home_dir}/etc/tracker.conf
	sed -i "s#base_path=.*#base_path=${file_dir}#" ${home_dir}/etc/tracker.conf
	add_log_cut fastdfs ${file_dir}/logs/*.log
	add_sys_env "PATH=${home_dir}/bin:\$PATH"
}

add_fastdfs_service(){

	ExecStart="${home_dir}/bin/fdfs_trackerd ${home_dir}/etc/tracker.conf start"
	conf_system_service
	add_system_service fdfs_trackerd ${home_dir}/init

	ExecStart="${home_dir}/bin/fdfs_storaged ${home_dir}/etc/storage.conf start"
	conf_system_service
	add_system_service fdfs_storaged ${home_dir}/init

}

fastdfs_install_ctl(){
	install_selcet
	fastdfs_install_set
	install_dir_set fastdfs
	download_unzip 
	fastdfs_install
	fastdfs_config
	add_fastdfs_service
	clear_install
}

nfs_install_ctl(){
	input_option "请输入要共享的目录:" "/data/nfs" "nfs_dir"
	nfs_dir=${input_value}
	yum install -y nfs-utils
	cat >>/etc/exports<<-EOF
	${nfs_dir} *(rw,sync)
	EOF
	[[ -d ${nfs_dir} ]] && mkdir -p ${nfs_dir}
	start_arg='y'
	service_control nfs
}

elk_install_ctl(){
	diy_echo "为了兼容性所有组件最好选择一样的版本" "${yellow}" "${info}"
	output_option "选择安装的组件" "elasticsearch logstash kibana filebeat" "elk_module"

	elk_module=${output_value[@]}
	if [[ ${output_value[@]} =~ 'elasticsearch' ]];then
		elasticsearch_install_ctl
	elif [[ ${output_value[@]} =~ 'logstash' ]];then
		logstash_install_ctl
	elif [[ ${output_value[@]} =~ 'kibana' ]];then
		kibana_install_ctl
	elif [[ ${output_value[@]} =~ 'filebeat' ]];then
		filebeat_install_ctl
	fi
	
}

elasticsearch_install_set(){
	output_option "选择安装模式" "单机 集群" "deploy_mode"
	if [[ ${deploy_mode} = '1' ]];then
		input_option "输入http端口号" "9200" "elsearch_port"
		input_option "输入tcp通信端口号" "9300" "elsearch_tcp_port"
	else
		input_option "请输入部署总个数($(diy_echo 必须是奇数 $red))" "3" "deploy_num_total"
		input_option '请输入所有部署elsearch的机器的ip地址,第一个为本机ip(多个使用空格分隔)' '192.168.1.1 192.168.1.2' 'elsearch_ip'
		elsearch_ip=(${input_value[@]})
		input_option '请输入每台机器部署elsearch的个数,第一个为本机部署个数(多个使用空格分隔)' '2 1' 'deploy_num_per'
		deploy_num_local=${deploy_num_per[0]}
		diy_echo "如果部署在多台机器,下面的起始端口号$(diy_echo 务必一致 $red)" "$yellow" "$warning"
		input_option "输入http端口号" "9200" "elsearch_port"
		input_option "输入tcp通信端口号" "9300" "elsearch_tcp_port"
	fi
}

elasticsearch_install(){

	useradd -M elsearch
	if [[ ${deploy_mode} = '1' ]];then
		mv ${tar_dir}/* ${home_dir}
		chown -R elsearch.elsearch ${home_dir}
		elasticsearch_conf
		add_elasticsearch_service
	fi
	if [[ ${deploy_mode} = '2' ]];then
		elasticsearch_server_list
		chown -R elsearch.elsearch ${tar_dir}
		for ((i=1;i<=${deploy_num_local};i++))
		do
			\cp -rp ${tar_dir} ${install_dir}/elsearch-node${i}
			home_dir=${install_dir}/elsearch-node${i}
			elasticsearch_conf
			add_elasticsearch_service
			elsearch_port=$((${elsearch_port}+1))
			elsearch_tcp_port=$((${elsearch_tcp_port}+1))
		done
	fi

}

elasticsearch_server_list(){

	local i
	local j
	local g
	j=0
	g=0

	for ip in ${elsearch_ip[@]}
	do
		for num in ${deploy_num_per[${j}]}
		do
			for ((i=0;i<num;i++))
			do
				discovery_hosts[$g]="\"${elsearch_ip[$j]}:$(((elsearch_tcp_port+$i)))\","
				g=$(((${g}+1)))
			done	
		done
		j=$(((${j}+1)))
	done
	#将最后一个值得逗号去掉
	discovery_hosts[$g-1]=$(echo ${discovery_hosts[$g-1]} | grep -Eo "[\"\.0-9:]{1,}")
	discovery_hosts=$(echo ${discovery_hosts[@]})
}

elasticsearch_conf(){
	get_ip
	if [[ ${deploy_mode} = '1' ]];then
		conf_dir=${home_dir}/config
		sed -i "s/#bootstrap.memory_lock.*/#bootstrap.memory_lock: false\nbootstrap.system_call_filter: false/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#network.host.*/network.host: ${local_ip}/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#http.port.*/http.port: ${elsearch_port}\nhttp.cors.enabled: true\nhttp.cors.allow-origin: \"*\"\ntransport.tcp.port: ${elsearch_tcp_port}/" ${conf_dir}/elasticsearch.yml
	else
		conf_dir=${home_dir}/config

		sed -i "s/#cluster.name.*/cluster.name: my-elsearch-cluster/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#node.name.*/node.name: ${local_ip}_node${i}\nnode.max_local_storage_nodes: 3/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#bootstrap.memory_lock.*/#bootstrap.memory_lock: false\nbootstrap.system_call_filter: false/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#network.host.*/network.host: ${local_ip}/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#http.port.*/http.port: ${elsearch_port}\nhttp.cors.enabled: true\nhttp.cors.allow-origin: \"*\"\ntransport.tcp.port: ${elsearch_tcp_port}/" ${conf_dir}/elasticsearch.yml
		sed -i "s/#discovery.zen.ping.unicast.hosts.*/discovery.zen.ping.unicast.hosts: [${discovery_hosts}]\ndiscovery.zen.ping_timeout: 30s/" ${conf_dir}/elasticsearch.yml
		sed -i "s/-Xms.*/-Xms512m/" ${conf_dir}/jvm.options
		sed -i "s/-Xmx.*/-Xmx512m/" ${conf_dir}/jvm.options
	fi

}

add_elasticsearch_service(){
	Type=forking
	User=elsearch
	ExecStart="${home_dir}/bin/elasticsearch"
	ARGS="-d"
	Environment="JAVA_HOME=$(echo $JAVA_HOME)"
	conf_system_service

	if [[ ${deploy_mode} = '1' ]];then
		add_system_service elsearch ${home_dir}/init
	else
		add_system_service elsearch-node${i} ${home_dir}/init
	fi
}

elasticsearch_install_ctl(){
	install_version elasticsearch
	install_selcet
	elasticsearch_install_set
	install_dir_set
	download_unzip
	elasticsearch_install
	clear_install
}

logstash_install_set(){
echo
}

logstash_install(){
	mv ${tar_dir}/* ${home_dir}
	mkdir -p ${home_dir}/config.d
	logstash_conf
	add_logstash_service
}

logstash_conf(){
	get_ip
	conf_dir=${home_dir}/config
	sed -i "s/# pipeline.workers.*/pipeline.workers: 4/" ${conf_dir}/logstash.yml
	sed -i "s/# pipeline.output.workers.*/pipeline.output.workers: 2/" ${conf_dir}/logstash.yml
	sed -i "s@# path.config.*@path.config: ${home_dir}/config.d@" ${conf_dir}/logstash.yml
	sed -i "s/# http.host.*/http.host: \"${local_ip}\" " ${conf_dir}/logstash.yml
	sed -i "s/-Xms.*/-Xms512m/" ${conf_dir}/jvm.options
	sed -i "s/-Xmx.*/-Xmx512m/" ${conf_dir}/jvm.options
}

add_logstash_service(){
	Type=simple
	ExecStart="${home_dir}/bin/logstash"
	Environment="JAVA_HOME=$(echo $JAVA_HOME)"
	conf_system_service
	add_system_service logstash ${home_dir}/init
}

logstash_install_ctl(){
	install_version logstash
	install_selcet
	logstash_install_set
	install_dir_set
	download_unzip
	logstash_install
	clear_install
}

kibana_install_set(){
	input_option "输入http端口号" "5601" "kibana_port"
	input_option "输入elasticsearch服务http地址" "127.0.0.1:9200" "elasticsearch_ip"
	elasticsearch_ip=${input_value}
}

kibana_install(){
	
	mv ${tar_dir}/* ${home_dir}
	kibana_conf
	add_kibana_service
}

kibana_conf(){
	get_ip
	conf_dir=${home_dir}/config
	sed -i "s/#server.port.*/server.port: ${kibana_port}/" ${conf_dir}/kibana.yml
	sed -i "s/#server.host.*/server.host: ${local_ip}/" ${conf_dir}/kibana.yml
	sed -i "s@#elasticsearch.url.*@elasticsearch.url: http://${elasticsearch_ip}@" ${conf_dir}/kibana.yml
}

add_kibana_service(){

	Type=simple
	ExecStart="${home_dir}/bin/kibana"
	conf_system_service 
	add_system_service kibana ${home_dir}/kibana_init
}

kibana_install_ctl(){
	install_version kibana
	install_selcet
	kibana_install_set
	install_dir_set
	download_unzip
	kibana_install
	clear_install
}

filebeat_install(){
	mv ${tar_dir}/* ${home_dir}
	filebeat_conf
	add_filebeat_service
}

filebeat_conf(){
	get_ip
	conf_dir=${home_dir}/config
}

add_filebeat_service(){
	ExecStart="${home_dir}/filebeat"
	conf_system_service 
	add_system_service filebeat ${home_dir}/init
}

filebeat_install_ctl(){
	install_version filebeat
	install_selcet
	#filebeat_install_set
	install_dir_set
	download_unzip
	filebeat_install
	clear_install
}

docker_install(){

	[[ -n `which docker 2>/dev/null` ]] && diy_echo "检测到可能已经安装docker请检查..." "${yellow}" "${warning}" && exit 1
	diy_echo "正在安装docker..." "" "${info}"
	system_optimize_yum
	if [[ ${os_release} < "7" ]];then
		yum install -y docker
	else
		wget -O /etc/yum.repos.d/docker-ce.repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo >/dev/null 2>&1
		yum install -y docker-ce
	fi
	mkdir /etc/docker
	cat >/etc/docker/daemon.json <<-'EOF'
	{
	  "registry-mirrors": [
	    "https://dockerhub.azk8s.cn",
	    "https://docker.mirrors.ustc.edu.cn",
	    "http://hub-mirror.c.163.com"
	  ],
	  "max-concurrent-downloads": 10,
	  "log-driver": "json-file",
	  "log-level": "warn",
	  "log-opts": {
		    "max-size": "10m",
		    "max-file": "3"
		    },
		  "data-root": "/var/lib/docker"
	  }
	EOF
}

k8s_env_check(){

	[[ ${os_release} < "7" ]] && diy_echo "k8s只支持CentOS7" "${red}" "${error}" && exit 1
	[[ -n `which kubectl 2>/dev/null` || -n `which kubeadm 2>/dev/null` || -n `which kubelet 2>/dev/null` ]] && diy_echo "k8s可能已经安装请检查..." "${red}" "${error}" && exit 1
	[[ -z `which docker 2>/dev/null` ]] && diy_echo "检测到未安装docker" "${yellow}" "${warning}" && docker_install
	if [[ ! -f /etc/yum.repos.d/kubernetes.repo ]];then
		cat >/etc/yum.repos.d/kubernetes.repo<<-EOF
		[kubernetes]
		name=Kubernetes
		baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
		enabled=1
		gpgcheck=0
		EOF
	fi
	#开启ipvs
	cat >/etc/modules-load.d/10-k8s-modules.conf<<-EOF
	br_netfilter
	ip_vs
	ip_vs_rr
	ip_vs_wrr
	ip_vs_sh
	nf_conntrack_ipv4
	nf_conntrack
	EOF
	modprobe br_netfilter ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack_ipv4 nf_conntrack
	cat >/etc/sysctl.d/95-k8s-sysctl.conf<<-EOF
	net.ipv4.ip_forward = 1
	net.bridge.bridge-nf-call-iptables = 1
	net.bridge.bridge-nf-call-ip6tables = 1
	net.bridge.bridge-nf-call-arptables = 1
	EOF
	sysctl -p /etc/sysctl.d/95-k8s-sysctl.conf >/dev/null
}

k8s_install_set(){

	output_option "选择安装方式" "kubeadm 二进制安装" install_method
	output_option "选择节点类型" "master node" node_type
	node_type=${output_value}
	if [[ ${node_type} = 'master' ]];then
		diy_echo "禁止master节点部署pod时某些组件可能会等待合适的node节点才会部署完成" "${yellow}" "${info}"
		input_option "是否允许master节点部署pod" "y" k8s_master_pod && k8s_master_pod=${ipput_value}
		output_option "选择网络组件" "flannel" k8s_net && k8s_net=${output_value}
		output_option "选择周边组件" "dashboard metrics heapster" k8s_module && k8s_module=${output_value[@]}
	else
		diy_echo "master节点执行kubeadm token list" "" "${info}"
		input_option "请输入master节点token" "22d578.d921a7cf51352441" tonken && tonken=${input_value[@]}
		input_option "请输入kube-apiserver地址" "192.168.1.2:6443" apiserver_ip && apiserver_ip=${input_value[@]}
	fi
}

k8s_env_conf(){
	
	systemctl stop firewalld
	systemctl disable firewalld

	#关闭selinux
	system_optimize_selinux
	system_optimize_Limits
	system_optimize_kernel
}

k8s_install(){
	system_optimize_yum
	if [[ ${version_number} = '1.11' || ${version_number} = '1.12' || ${version_number} = '1.13' ]];then
		yum install -y kubectl-${online_select_version} kubeadm-${online_select_version} kubelet-${online_select_version} kubernetes-cni-0.6.0
	elif [[ ${version_number} = '1.14' ]];then
		yum install -y kubectl-${online_select_version} kubeadm-${online_select_version} kubelet-${online_select_version} kubernetes-cni-0.7.5
	fi
	if [[ $? = '0' ]];then
		diy_echo "kubectl kubeadm kubelet安装成功." "" "${info}"
		systemctl enable kubelet docker
		systemctl start docker
	else
		diy_echo "kubectl kubeadm kubelet安装失败!" "" "${error}"
		exit 1
	fi
}

k8s_mirror(){
	diy_echo "正在获取需要的镜像..." "" "${info}"
	if [[ ${node_type} = 'master' ]];then
		images_name=$(kubeadm config images list 2>/dev/null | grep -Eo 'kube.*|pause.*|etcd.*|coredns.*' | awk -F : '{print $1}')
		tag=$(kubeadm config images list 2>/dev/null | grep -Eo 'kube.*|pause.*|etcd.*|coredns.*' | awk -F : '{print $2}')
		images_name=(${images_name})
		tag=(${tag})
	else
		images_name=$(kubeadm config images list 2>/dev/null | grep -Eo 'kube-proxy.*|pause.*' | awk -F : '{print $1}')
		tag=$(kubeadm config images list 2>/dev/null | grep -Eo 'kube-proxy.*|pause.*' | awk -F : '{print $2}')
		images_name=(${images_name})
		tag=(${tag})
	fi
	
	if [[ ${version_number} = '1.11' ]];then
		platform=-amd64
	else
		platform=
	fi
	diy_echo "正在拉取需要的镜像..." "" "${info}"
	images_number=${#images_name[@]}
	#循环次数
	cycles=`expr ${images_number}-1`
	for ((i=0;i<=${cycles};i++))
	do
		docker pull rootww/${images_name[$i]}:${tag[$i]} || \
		docker pull mirrorgooglecontainers/${images_name[$i]}:${tag[$i]} && \
		docker tag rootww/${images_name[$i]}:${tag[$i]} k8s.gcr.io/${images_name[$i]}${platform}:${tag[$i]} || \
		docker tag mirrorgooglecontainers/${images_name[$i]}:${tag[$i]} k8s.gcr.io/${images_name[$i]}${platform}:${tag[$i]} && \
		docker rmi rootww/${images_name[$i]}:${tag[$i]} || \
		docker rmi mirrorgooglecontainers/${images_name[$i]}:${tag[$i]}
	done

}

k8s_conf_before(){
	
	#cgroup-driver驱动配置为和docker一致
	cgroup_driver=`docker info | grep 'Cgroup' | cut -d' ' -f3`
	KUBELET_EXTRA_ARGS="--fail-swap-on=false --runtime-cgroups=/systemd/system.slice --kubelet-cgroups=/systemd/system.slice --cgroup-driver=${cgroup_driver}"
	sed -i "s#KUBELET_EXTRA_ARGS=.*#KUBELET_EXTRA_ARGS=\"${KUBELET_EXTRA_ARGS}\"#" /etc/sysconfig/kubelet

}

k8s_init_config(){
	get_ip
	wget -O /etc/kubernetes/kubeadm_init.yaml https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/kubeadm/init_config_${version_number}.yaml
	sed -i "s/name: 127.0.0.1/name: ${local_ip}/" /etc/kubernetes/kubeadm_init.yaml
	sed -i "s/advertiseAddress: 127.0.0.1/advertiseAddress: ${local_ip}/" /etc/kubernetes/kubeadm_init.yaml
	sed -i "s/kubernetesVersion: .*/kubernetesVersion: v${online_select_version}/" /etc/kubernetes/kubeadm_init.yaml

}

k8s_init(){

	if [[ ${node_type} = 'master' ]];then
		diy_echo "正在初始化k8s..." "" "${info}"
		kubeadm init --config /etc/kubernetes/kubeadm_init.yaml --ignore-preflight-errors=Swap --ignore-preflight-errors=SystemVerification >/dev/null
		if [[ $? = '0' ]];then
			diy_echo "初始化k8s成功." "" "${info}"
			mkdir -p $HOME/.kube
			\cp -r /etc/kubernetes/admin.conf $HOME/.kube/config

		else
			diy_echo "初始化k8s失败!" "" "${error}"
			diy_echo "使用kubectl reset重置" "${yellow}" "${info}"
			exit 1
		fi
	fi
	
	if [[ ${node_type} = 'node' ]];then
		kubeadm join --token ${tonken} ${apiserver_ip} --node-name=${local_ip} --ignore-preflight-errors=Swap --discovery-token-unsafe-skip-ca-verification
		if [[ $? = '0' ]];then
			diy_echo "加入k8s集群成功." "" "${info}"
		else
			diy_echo "加入k8s集群失败!" "" "${error}"
			diy_echo "使用kubeadm reset重置" "${yellow}" "${info}"
			exit 1
		fi
	fi
}

k8s_conf_after(){
	diy_echo "配置k8s命令自动补全" "" "${info}"
	if [[ -z $(cat ~/.bashrc | grep 'source <(kubectl completion bash)') ]];then
		echo "source <(kubectl completion bash)" >> ~/.bashrc
	fi

	if [[ $(yes_or_no ${k8s_master_pod}) = 0 ]];then
		diy_echo "配置k8s允许master节点部署pod" "" "${info}"
		kubectl taint nodes --all node-role.kubernetes.io/master-
	elif [[ $(yes_or_no ${k8s_master_pod}) = 1 ]];then
		diy_echo "配置k8s禁止master节点部署pod" "" "${info}"
		kubectl taint nodes ${local_ip} node-role.kubernetes.io/master=true:NoSchedule
	fi

}

k8s_apply(){

	if [[ ${k8s_net[@]} =~ 'flannel' ]];then
		diy_echo "正在添加flannel..." "" "${info}"
		kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
	fi
	if [[ ${k8s_module[@]} =~ 'dashboard' ]];then
		diy_echo "正在添加dashboard..." "" "${info}"
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/dashboard/kubernetes-dashboard.yaml && \
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/dashboard/kubernetes-dashboard-admin.yaml && \
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/dashboard/kubernetes-dashboard-user.yaml
	fi
	if [[ ${k8s_module[@]} =~ 'metrics' ]];then
		diy_echo "正在添加metrics监控..." "" "${info}"
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/metrics-server/auth-delegator.yaml && \
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/metrics-server/auth-reader.yaml && \
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/metrics-server/metrics-apiservice.yaml && \
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/metrics-server/metrics-server-deployment.yaml && \
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/metrics-server/metrics-server-service.yaml && \
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/metrics-server/resource-reader.yaml
	fi
	if [[ ${k8s_module[@]} =~ 'heapster' ]];then
		diy_echo "正在添加heapster监控..." "" "${info}"
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/heapster/heapster.yaml && \
		kubectl apply -f https://raw.githubusercontent.com/hebaodanroot/ops_script/master/k8s/heapster/resource-reader.yaml
	fi

}

k8s_install_ctl(){
	install_version k8s
	install_selcet
	k8s_install_set
	k8s_env_check
	online_version
	k8s_env_conf
	k8s_install
	k8s_mirror
	k8s_conf_before
	k8s_init_config
	k8s_init
	k8s_conf_after
	k8s_apply
}

etcd_install(){
	yum install -y etcd
}

mysql_index_statistics(){

while true
do
	echo -e "${info} 是否进行统计关键MySQL指标[y/n]?"
	stty erase '^H' && read -p "(默认y):" Whether
	if [[ -z ${Whether} || ! -z ${Whether} && ${Whether} = y || ${Whether} = Y ]];then
		Whether=y
		break 
	elif [[ ! -z ${Whether} && ${Whether} = n || ${Whether} = N ]];then
		exit
	else 
		echo -e "${warning} 输入正确的指令!" 
	fi
done
mysql_user_passwd
mysql_service_check
mysql_password_check
#mysql版本
mysql -V

}

zookeeper_install_set(){

	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'

	if [[ ${deploy_mode} = '1' ]];then
		input_option '请设置zookeeper的客户端口号' '2181' 'zookeeper_connection_port'
	elif [[ ${deploy_mode} = '2' ]];then
		input_option "请输入部署总个数($(diy_echo 必须是奇数 $red))" '3' 'deploy_num_total'
		input_option '请输入所有部署zookeeper的机器的ip地址,第一个必须为本机ip(多个使用空格分隔)' '192.168.1.1 192.168.1.2' 'zookeeper_ip'
		zookeeper_ip=(${input_value[@]})
		input_option '请输入每台机器部署zookeeper的个数,第一个必须为本机部署个数(多个使用空格分隔)' '2 1' 'deploy_num_per'
		deploy_num_local=${deploy_num_per[0]}
		diy_echo "如果部署在多台机器,下面的起始端口号$(diy_echo 务必一致 $red)" "$yellow" "$warning"

		input_option '请设置zookeeper的客户端口号' '2181' 'zookeeper_connection_port'
		input_option '请设置zookeeper的心跳端口号' '2888' 'zookeeper_heartbeat_port'
		input_option '请设置zookeeper的信息端口号' '3888' 'zookeeper_info_port'
		diy_echo "部署Zookeeper的机器的ip是$(diy_echo ${zookeeper_ip} $red)" "$plain" "$info"
		diy_echo "每台机器部署Zookeeper的个数是$(diy_echo ${zookeeper_num} $red)" "$plain" "$info"
		diy_echo "zookeeper的连接端口号是$(diy_echo ${zookeeper_connection_port} $red)" "$plain" "$info"
		diy_echo "zookeeper的心跳端口号是$(diy_echo ${zookeeper_heartbeat_port} $red)" "$plain" "$info"
		diy_echo "zookeeper的信息端口号是$(diy_echo ${zookeeper_info_port} $red)" "$plain" "$info"
		diy_echo "press any key to continue" "$plain" "$info"
		read
	fi
	
}

zookeeper_install(){
	
	if [[ ${deploy_mode} = '1' ]];then
		mv ${tar_dir} ${home_dir}
		zookeeper_config
		add_zookeeper_service
	fi
	
	if [[ ${deploy_mode} = '2' ]];then
		add_zookeeper_server_list
		for ((i=1;i<=${deploy_num_local};i++))
		do
			\cp -rp ${tar_dir} ${install_dir}/zookeeper-node${i}
			home_dir=${install_dir}/zookeeper-node${i}
			zookeeper_config
			add_zookeeper_service
			zookeeper_connection_port=$((${zookeeper_connection_port}+1))
			zookeeper_heartbeat_port=$((${zookeeper_heartbeat_port}+1))
			zookeeper_info_port=$((${zookeeper_info_port}+1))
		done
	fi

}

add_zookeeper_server_list(){

	[[ -f /tmp/zoo.cfg ]] && rm -rf /tmp/zoo.cfg
	local i
	local j
	j=0
	serverid='1'
	#循环取ip,次数等于部署机器个数
	for ip in ${zookeeper_ip[@]}
	do
		#循环取每台机器部署个数
		for num in ${deploy_num_per[${j}]}
		do
			for ((i=0;i<num;i++))
			do
				echo "server.$(((serverid++)))=${zookeeper_ip[$j]}:$(((zookeeper_heartbeat_port+$i))):$(((zookeeper_info_port+$i)))">>/tmp/zoo.cfg
			done	
		done
		j=$(((${j}+1)))
	done

}

zookeeper_config(){
	mkdir -p ${home_dir}/{logs,data}
	conf_dir=${home_dir}/conf
	cp ${conf_dir}/zoo_sample.cfg ${conf_dir}/zoo.cfg

	cat > ${conf_dir}/java.env <<-'EOF'
	#!/bin/sh
	export PATH
	# heap size MUST be modified according to cluster environment
	export JVMFLAGS="-Xms512m -Xmx512m -Xmn128m $JVMFLAGS"
	EOF

	sed -i "s#dataDir=/tmp/zookeeper#dataDir=${home_dir}/data#" ${conf_dir}/zoo.cfg
	sed -i "s#clientPort=.*#clientPort=${zookeeper_connection_port}#" ${conf_dir}/zoo.cfg
	sed -i '/ZOOBIN="${BASH_SOURCE-$0}"/i ZOO_LOG_DIR='${home_dir}'/logs' ${home_dir}/bin/zkServer.sh
	if [[ ${deploy_mode} = '2' ]];then
		cat /tmp/zoo.cfg >>${conf_dir}/zoo.cfg
		myid=$(cat /tmp/zoo.cfg | grep -E "${zookeeper_ip[0]}:${zookeeper_heartbeat_port}:${zookeeper_info_port}" | grep -Eo "server\.[0-9]{1,2}" | grep -oE "[0-9]{1,2}")
		cat > ${home_dir}/data/myid <<-EOF
		${myid}
		EOF
		add_log_cut zookeeper-node${i} ${home_dir}/logs/zookeeper.out
	else
		add_log_cut zookeeper ${home_dir}/logs/zookeeper.out
	fi
}

add_zookeeper_service(){
	Type="forking"
	ExecStart="${home_dir}/bin/zkServer.sh start"
	Environment="JAVA_HOME=$(echo $JAVA_HOME) ZOO_LOG_DIR=${home_dir}/logs"
	conf_system_service 

	if [[ ${deploy_mode} = '1' ]];then
		add_system_service zookeeper ${home_dir}/init
	else
		add_system_service zookeeper-node${i} ${home_dir}/init
	fi
}

zookeeper_install_ctl(){
	install_version zookeeper
	install_selcet
	zookeeper_install_set
	install_dir_set
	download_unzip
	zookeeper_install
	clear_install
}

kafka_install_set(){
	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'
	if [[ ${deploy_mode} = '1' ]];then
		input_option '请设置kafka的端口号' '9092' 'kafka_port'
	elif [[ ${deploy_mode} = '2' ]];then
		input_option '请输入本机部署个数' '1' 'deploy_num_local'
		input_option '请设置kafka的起始端口号' '9092' 'kafka_port'
		diy_echo "集群内broker.id不能重复" "${yellow}" "${info}"
		input_option '请设置kafka的broker id' '0' 'kafka_id'
	fi
	input_option '请设置kafka数据目录' '/data/kafka' 'kafka_data_dir'
	diy_echo "此处建议使用单独zookeeper服务" "${yellow}" "${info}"
	input_option '请设置kafka连接的zookeeper地址池' '192.168.1.2:2181 192.168.1.3:2181 192.168.1.4:2181' 'zookeeper_ip'
	zookeeper_ip=(${input_value[@]})
}

kafka_install(){

	if [[ ${deploy_mode} = '1' ]];then
		mv ${tar_dir} ${home_dir}
		kafka_config
		add_kafka_service
	fi
	
	if [[ ${deploy_mode} = '2' ]];then
		
		for ((i=1;i<=${deploy_num_local};i++))
		do
			cp -rp ${tar_dir} ${install_dir}/kafka-node${i}
			home_dir=${install_dir}/kafka-node${i}
			kafka_config
			add_kafka_service
			kafka_port=$((${kafka_port}+1))
		done
	fi
}

kafka_config(){
	mkdir -p ${home_dir}/{logs,data}
	conf_dir=${home_dir}/config
	[[ -n ${kafka_id} ]] && sed -i "s/broker.id=0/broker.id=${kafka_id}/" ${conf_dir}/server.properties
	sed -i "/broker.id=.*/aport=${kafka_port}" ${conf_dir}/server.properties
	sed -i "s/log.dirs=.*/log.dirs=${kafka_data_dir}/${kafka_port}" ${conf_dir}/server.properties
	zookeeper_ip="${zookeeper_ip[@]}"
	zookeeper_connect=$(echo ${zookeeper_ip} | sed 's/ /,/g')
	sed -i "s/zookeeper.connect=localhost:2181/zookeeper.connect=${zookeeper_connect}/" ${conf_dir}/server.properties
}

add_kafka_service(){
	Type=simple
	ExecStart="${home_dir}/bin/kafka-server-start.sh ${home_dir}/config/server.properties"
	ExecStop="${home_dir}/bin/kafka-server-stop.sh"
	Environment="JAVA_HOME=$(echo $JAVA_HOME) KAFKA_HOME=${home_dir}"
	conf_system_service 

	if [[ ${deploy_mode} = '1' ]];then
		add_system_service kafka ${home_dir}/init
	else
		add_system_service kafka-node${i} ${home_dir}/init
	fi
}

kafka_install_ctl(){
	install_version kafka
	install_selcet
	kafka_install_set
	install_dir_set
	download_unzip
	kafka_install
	clear_install
}

activemq_install_set(){
	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'

	if [[ ${deploy_mode} = '2' ]];then
		output_option '请选择集群模式' 'Master-slave(高可用HA) Broker-clusters(负载均衡SLB) 混合模式' 'cluster_mode'
		if [[ ${cluster_mode} = '1' ]];then
			diy_echo '目前是基于共享文件的方式高可用方案' '' "$info"
			input_option '请输入共享文件夹目录' '/data/activemq' 'shared_dir'
			shared_dir=${input_value}
			input_option '请输入本机部署个数' '2' 'deploy_num'
		fi
		
		if [[ ${cluster_mode} = '2' ]];then
			input_option '请输入本机部署个数' '2' 'deploy_num'
		fi
		
		if [[ ${cluster_mode} = '3' ]];then
			input_option '请输入部署broker个数' '2' 'broker_num'
			input_option '请输入共享文件夹目录' '/data/activemq' 'shared_dir'
			shared_dir=${input_value}
			input_option '请输入本机部署个数' '2' 'deploy_num'
		fi
	fi
	input_option '请设置连接activemq的起始端口号' '61616' 'activemq_conn_port'
	input_option '请设置管理activemq的起始端口号' '8161' 'activemq_mana_port'
	input_option '请设置连接activemq的用户名' 'system' 'activemq_username'
	activemq_username=${input_value}
	input_option '请设置连接activemq的密码' 'manager' 'activemq_userpasswd'
	activemq_userpasswd=${input_value}
	echo -e "${info} press any key to continue"
	read
	
}

activemq_install(){
	
	if [[ ${deploy_mode} = '1' ]];then
		mv ${tar_dir} ${home_dir}
		activemq_config
		add_activemq_service
	fi
	if [[ ${deploy_mode} = '2' ]];then

		activemq_conn_port_default=${activemq_conn_port}
		activemq_mana_port_default=${activemq_mana_port}
		activemq_networkconn_port_default=${activemq_conn_port}

		for ((i=1;i<=${deploy_num};i++))
		do

			if [[ ${cluster_mode} = '1' || ${cluster_mode} = '2' ]];then
				\cp -rp ${tar_dir} ${install_dir}/activemq-node${i}
				home_dir=${install_dir}/activemq-node${i}
				activemq_config
				add_activemq_service
				activemq_conn_port=$((${activemq_conn_port}+1))
				activemq_mana_port=$((${activemq_mana_port}+1))
			fi
			
			if [[ ${cluster_mode} = '3' ]];then	

				#平均数
				average_value=$(((${deploy_num}/${broker_num})))
				#加权系数[0-(broker_num)]之间做为broker号
				weight_factor=$(((${i} % ${broker_num})))
				
				activemq_conn_port=${activemq_conn_port_default}
				activemq_mana_port=${activemq_mana_port_default}
				activemq_networkconn_port=${activemq_networkconn_port_default}
					
				activemq_conn_port=$((${activemq_conn_port}+${weight_factor}))
				activemq_mana_port=$((${activemq_mana_port}+${weight_factor}))
				#配置broker连接端口目前配置为环网连接
				if (( ${weight_factor} == $(((${broker_num} - 1))) ));then
					activemq_networkconn_port=${activemq_networkconn_port_default}
				else
					activemq_networkconn_port=$(((${activemq_networkconn_port_default}+${weight_factor}+1)))
				fi
					
				\cp -rp ${tar_dir} ${install_dir}/activemq-broker${weight_factor}-node${i}
				home_dir=${install_dir}/activemq-broker${weight_factor}-node${i}
				activemq_config
				add_activemq_service
			fi
		done
	fi

}

activemq_config(){

	cat > /tmp/activemq.xml.tmp << 'EOF'
        <plugins> 
           <simpleAuthenticationPlugin> 
                 <users> 
                      <authenticationUser username="${activemq.username}" password="${activemq.password}" groups="users,admins"/> 
                 </users> 
           </simpleAuthenticationPlugin> 
        </plugins>
EOF
	
	cat > /tmp/activemq.xml.networkConnector.tmp << EOF
				<networkConnectors>
						<networkConnector uri="static:(tcp://0.0.0.0:61616)" duplex="true" userName="${activemq_username}" password="${activemq_userpasswd}"/>
				</networkConnectors>	
EOF


	if [[ ${deploy_mode} = '1' ]];then
		#插入文本内容
		sed -i '/<\/persistenceAdapter>/r /tmp/activemq.xml.tmp' ${home_dir}/conf/activemq.xml
		#注释无用的消息协议只开启tcp
		sed -i 's#<transportConnector name#<!-- <transportConnector name#' ${home_dir}/conf/activemq.xml
		sed -i 's#maxFrameSize=104857600"/>#maxFrameSize=104857600"/> -->#' ${home_dir}/conf/activemq.xml
		sed -i 's#<!-- <  name="openwire".*maxFrameSize=104857600"/> -->#<transportConnector name="openwire" uri="tcp://0.0.0.0:61616?maximumConnections=1000\&amp;wireFormat.maxFrameSize=104857600"/>#' ${home_dir}/conf/activemq.xml
		#配置链接用户密码
		sed -i 's#activemq.username=system#activemq.username='${activemq_username}'#' ${home_dir}/conf/credentials.properties
		sed -i 's#activemq.password=manager#activemq.password='${activemq_userpasswd}'#' ${home_dir}/conf/credentials.properties
	elif [[ ${deploy_mode} = '2' ]];then
		
			#插入文本内容
			sed -i '/<\/persistenceAdapter>/r /tmp/activemq.xml.tmp' ${home_dir}/conf/activemq.xml
			#注释无用的消息协议只开启tcp
			sed -i 's#<transportConnector name#<!-- <transportConnector name#' ${home_dir}/conf/activemq.xml
			sed -i 's#maxFrameSize=104857600"/>#maxFrameSize=104857600"/> -->#' ${home_dir}/conf/activemq.xml
			sed -i 's#<!-- <transportConnector name="openwire".*maxFrameSize=104857600"/> -->#<transportConnector name="openwire" uri="tcp://0.0.0.0:61616?maximumConnections=1000\&amp;wireFormat.maxFrameSize=104857600"/>#' ${home_dir}/conf/activemq.xml
			#配置链接用户密码
			sed -i 's#activemq.username=system#activemq.username='${activemq_username}'#' ${home_dir}/conf/credentials.properties
			sed -i 's#activemq.password=manager#activemq.password='${activemq_userpasswd}'#' ${home_dir}/conf/credentials.properties

		if [[ ${cluster_mode} = '1' ]];then
			sed -i 's#<kahaDB directory="${activemq.data}/kahadb"/>#<kahaDB directory="'${shared_dir}'"/>#' ${home_dir}/conf/activemq.xml

		elif [[ ${cluster_mode} = '2' ]];then
			sed -i 's#brokerName="localhost"#brokerName="broker'${i}'"#' ${home_dir}/conf/activemq.xml
			sed -i '/<\/plugins>/r /tmp/activemq.xml.networkConnector.tmp' ${home_dir}/conf/activemq.xml
			sed -i 's#<transportConnector name="openwire" uri="tcp://0.0.0.0:61616#<transportConnector name="openwire" uri="tcp://0.0.0.0:'${activemq_conn_port}'#' ${home_dir}/conf/activemq.xml
			sed -i 's#<property name="port" value="8161"/>#<property name="port" value="'${activemq_mana_port}'"/>#' ${home_dir}/conf/jetty.xml
		elif [[ ${cluster_mode} = '3' ]];then
			sed -i 's#brokerName="localhost"#brokerName="broker'${weight_factor}'"#' ${home_dir}/conf/activemq.xml
			sed -i 's#<kahaDB directory="${activemq.data}/kahadb"/>#<kahaDB directory="'${shared_dir}'/broker'${weight_factor}'"/>#' ${home_dir}/conf/activemq.xml
			sed -i '/<\/plugins>/r /tmp/activemq.xml.networkConnector.tmp' ${home_dir}/conf/activemq.xml
			sed -i 's#<networkConnector uri="static:(tcp://0.0.0.0:61616)#<networkConnector uri="static:(tcp://0.0.0.0:'${activemq_networkconn_port}')#' ${home_dir}/conf/activemq.xml
			sed -i 's#<transportConnector name="openwire" uri="tcp://0.0.0.0:61616#<transportConnector name="openwire" uri="tcp://0.0.0.0:'${activemq_conn_port}'#' ${home_dir}/conf/activemq.xml
			sed -i 's#<property name="port" value="8161"/>#<property name="port" value="'${activemq_mana_port}'"/>#' ${home_dir}/conf/jetty.xml
		fi
	fi
}

add_activemq_service(){

	Type="forking"
	Environment="JAVA_HOME=$(echo $JAVA_HOME)"
	ExecStart="${home_dir}/bin/activemq start"
	ExecStop="${home_dir}/bin/activemq stop"
	conf_system_service
	if [[ ${deploy_mode} = '1' ]];then
		add_system_service activemq ${home_dir}/init
	fi
	if [[ ${deploy_mode} = '2' ]];then
		if [[ ${cluster_mode} = '1' ]];then		
			add_system_service activemq-node${i} ${home_dir}/init
		fi
		if [[ ${cluster_mode} = '2' ]];then	
			add_system_service activemq-broker${i}-node${i} ${home_dir}/init
		fi
		if [[ ${cluster_mode} = '3' ]];then
			add_system_service activemq-broker${weight_factor}-node${i} ${home_dir}/init
		fi
	fi

}

activemq_install_ctl(){
	install_version activemq
	install_selcet
	activemq_install_set
	install_dir_set
	download_unzip
	activemq_install
	clear_install
}

rocketmq_install_set(){

	output_option '请选择安装模式' '单机模式 集群模式' 'deploy_mode'

	if [[ ${deploy_mode} = '2' ]];then
	
		echo -e "${info} Rocket集群模式比较灵活，可以有多个主节点，每个主节点可有多个从节点，互为主从的broker名字必须相同"
		input_option '请输入部署rocketmq的总个数' '4' 'deploy_num_total'
		input_option '请输入部署broker个数(主节点个数)' '2' 'broker_num'

		if [[ ${broker_num} > ${deploy_num_total} ]];then
			diy_echo '部署个数有错误重新输入' '' "$error"
		fi
		
		input_option '请输入所有部署rocketmq的ip地址,默认第一个为本机ip(多个使用空格分隔)' '192.168.1.1 192.168.1.2' 'rocketmq_ip'
		rocketmq_ip=(${input_value[@]})
		input_option '请输入每台机器部署rocketmq的个数,默认第一个为本机个数(多个使用空格分隔)' "2 2" 'deploy_num_per'
		deploy_num_local=${deploy_num_per[0]}

	fi
	
	diy_echo "如果部署在多台机器,下面的起始端口号$(diy_echo 务必一致 $red)" "$yellow" "$warning"
	input_option '请设置rocketmq-broker的起始端口号' '10911' 'rocketmq_broker_port'
	input_option '请设置rocketmq-namesrv的起始端口号' '9876' 'rocketmq_namesrv_port'
	echo -e "${info} press any key to continue"
	read

}

borker_name_set(){
	input_option '输入broker名字' 'broker-a' 'broker_name'
	broker_name=(${input_value[@]})
}

node_type_set(){

	input_option '输入节点类型(主M/从S)' 'M' 'node_type'
	node_type=(${input_value[@]})
	if [[ ${node_type} = 'M' || ${node_type} = 'm' ]];then
		node_type='m'
	elif [[ ${node_type} = 'S' || ${node_type} = 's' ]];then
		node_type='s'
	else
		echo -e "${error} 输入错误请重新设置"
		node_type_set
	fi
}

rocketmq_install(){ 

	if [[ ${deploy_mode} = '1' ]];then
		mv ${tar_dir} ${home_dir}
		rocketmq_namesrvaddr
		rocketmq_config
		add_rocketmq_service
	fi
		
	if [[ ${deploy_mode} = '2' ]];then
		rocketmq_namesrvaddr
		for ((i=1;i<=${deploy_num_local};i++))
		do
			borker_name_set
			node_type_set
			\cp -rp ${tar_dir} ${install_dir}/rocketmq-${broker_name}-${node_type}-node${i}
			home_dir=${install_dir}/rocketmq-${broker_name}-${node_type}-node${i}
			rocketmq_config
			add_rocketmq_service
			rocketmq_broker_port=$((${rocketmq_broker_port}+4))
			rocketmq_namesrv_port=$((${rocketmq_namesrv_port}+1))
		done
	fi

	
}

rocketmq_namesrvaddr(){
	local i
	local j
	j=0
	namesrvaddr=''
	#循环取ip,次数等于部署机器个数
	for ip in ${rocketmq_ip[@]}
	do
		#循环取每台机器部署个数
		for num in ${deploy_num_per[${j}]}
		do
			for ((i=0;i<num;i++))
			do
				namesrvaddr=${namesrvaddr}${ip}:$(((${rocketmq_namesrv_port}+${i})))\;
			done	
		done
		j=$(((${j}+1)))
	done

}

rocketmq_config(){

	cat >${home_dir}/conf/namesrv.properties<<-EOF
	rocketmqHome=
	kvConfigPath=
	listenPort=9876
	EOF
	cat >${home_dir}/conf/broker.properties<<-EOF
	#所属集群名字
	brokerClusterName=rocketmq-cluster
	#broker名字，注意此处不同的配置文件填写的不一样
	brokerName=broker-a
	#0 表示 Master，>0 表示 Slave
	brokerId=0
	#nameServer地址，分号分割
	namesrvAddr=127.0.0.1:9876
	#在发送消息时，自动创建服务器不存在的topic，默认创建的队列数
	defaultTopicQueueNums=4
	#是否允许 Broker 自动创建Topic，建议线下开启，线上关闭
	autoCreateTopicEnable=true
	#是否允许 Broker 自动创建订阅组，建议线下开启，线上关闭
	autoCreateSubscriptionGroup=true
	#Broker 对外服务的监听端口
	brokerIP1=
	listenPort=10911
	#删除文件时间点，默认凌晨 4点
	deleteWhen=04
	#文件保留时间，默认 48 小时
	fileReservedTime=120
	#commitLog每个文件的大小默认1G
	mapedFileSizeCommitLog=1073741824
	#ConsumeQueue每个文件默认存30W条，根据业务情况调整
	mapedFileSizeConsumeQueue=300000
	#destroyMapedFileIntervalForcibly=120000
	#redeleteHangedFileInterval=120000
	#检测物理文件磁盘空间
	diskMaxUsedSpaceRatio=88
	#存储路径
	storePathRootDir=/laihui/base-app/roketmq-cluster/rocketmq-M1/data/store
	#commitLog 存储路径
	storePathCommitLog=/laihui/base-app/roketmq-cluster/rocketmq-M1/data/store/commitlog
	#限制的消息大小
	#maxMessageSize=65536
	#flushCommitLogLeastPages=4
	#flushConsumeQueueLeastPages=2
	#flushCommitLogThoroughInterval=10000
	#flushConsumeQueueThoroughInterval=60000
	#Broker 的角色
	#- ASYNC_MASTER 异步复制Master
	#- SYNC_MASTER 同步双写Master
	#- SLAVE
	brokerRole=ASYNC_MASTER
	#刷盘方式
	#- ASYNC_FLUSH 异步刷盘
	#- SYNC_FLUSH 同步刷盘
	flushDiskType=ASYNC_FLUSH
	#checkTransactionMessageEnable=false
	#发消息线程池数量
	#sendMessageThreadPoolNums=128
	#发送消息是否使用可重入锁
	#useReentrantLockWhenPutMessage:true
	#拉消息线程池数量
	#pullMessageThreadPoolNums=128
	EOF

	sed -i "s#rocketmqHome=#rocketmqHome=${home_dir}#" ${home_dir}/conf/namesrv.properties
	sed -i "s#kvConfigPath=#kvConfigPath=${home_dir}/data/namesrv/kvConfig.json#" ${home_dir}/conf/namesrv.properties
	sed -i "s#listenPort=9876#listenPort=${rocketmq_namesrv_port}#" ${home_dir}/conf/namesrv.properties
	
	sed -i "s#brokerName=broker-a#brokerName=${broker_name}#" ${home_dir}/conf/broker.properties
	[[ ${node_type} = 's' ]] && sed -i "s#brokerId=0#brokerId=1#" ${home_dir}/conf/broker.properties

	sed -i "s#namesrvAddr=127.0.0.1:9876#namesrvAddr=${namesrvaddr}#" ${home_dir}/conf/broker.properties
	sed -i "s#brokerIP1=#brokerIP1=$(hostname -I)#" ${home_dir}/conf/broker.properties
	sed -i "s#listenPort=10911#listenPort=${rocketmq_broker_port}#" ${home_dir}/conf/broker.properties
	sed -i "s#storePathRootDir=.*#storePathRootDir=${home_dir}/data/store#" ${home_dir}/conf/broker.properties
	sed -i "s#storePathCommitLog=.*#storePathCommitLog=${home_dir}/data/store/commitlog#" ${home_dir}/conf/broker.properties
	[[ ${node_type} = 's' ]] && sed -i "s#brokerRole=ASYNC_MASTER#brokerRole=SLAVE#" ${home_dir}/conf/broker.properties
	sed -i 's#${user.home}/logs/rocketmqlogs#'${home_dir}'/logs#g' ${home_dir}/conf/*.xml
	sed -i 's#-server -Xms4g -Xmx4g -Xmn2g -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=320m#-server -Xms512m -Xmx512m -Xmn256m -XX:MetaspaceSize=96m -XX:MaxMetaspaceSize=256m#' ${home_dir}/bin/runserver.sh
	sed -i 's#-server -Xms8g -Xmx8g -Xmn4g#-server -Xms512m -Xmx512m -Xmn256m#' ${home_dir}/bin/runbroker.sh
}

add_rocketmq_service(){
	Type="simple"
	Environment="JAVA_HOME=$(echo ${JAVA_HOME})"

	if [[ ${deploy_mode} = '1' ]];then
		ExecStart="${home_dir}/bin/mqbroker -c ${home_dir}/conf/broker.properties"
		conf_system_service
		add_system_service rocketmq-broker ${home_dir}/init
		ExecStart="${home_dir}/bin/mqnamesrv -c ${home_dir}/conf/namesrv.properties"
		conf_system_service
		add_system_service rocketmq-namesrv ${home_dir}/init
	elif [[ ${deploy_mode} = '2' ]];then
		ExecStart="${home_dir}/bin/mqbroker -c ${home_dir}/conf/broker.properties"
		conf_system_service
		add_system_service rocketmq-${broker_name}-${node_type}-node${i} ${home_dir}/init
		ExecStart="${home_dir}/bin/mqnamesrv -c ${home_dir}/conf/namesrv.properties"
		conf_system_service
		add_system_service rocketmq-namesrv-${broker_name}-${node_type}-node${i} ${home_dir}/init
	fi
	
}

rocketmq_install_ctl(){
	install_version rocketmq
	install_selcet
	rocketmq_install_set
	install_dir_set
	download_unzip
	rocketmq_install
	clear_install
}

add_sysuser(){
  echo -e "${info} Start adding system users"
  while true
  do
    read -p "Please enter a new username:" name
    NAME=`awk -F':' '{print $1}' /etc/passwd|grep -wx $name 2>/dev/null|wc -l`
    if [[ ${name} = '' ]];then
      echo -e "${error} Username cannot be empty, please re-enter"
      continue
    elif [ $NAME -eq 1 ];then
      echo -e "${error} User name already exists, please re-enter"
      continue
    fi
    useradd ${name}
    if [ $? = '0' ];then
      echo -e "${info} Added system user success"
    else
      echo -e "${error} Failed to add system user"
      exit
    fi
   break
  done
  #create password
  while true
  do
    read -p "Create a password for $name:" pass1
      if [ ${#pass1} -eq 0 ];then
        echo "Password cannot empty please re-enter"
        continue
      fi
      read -p "Please enter your password again:" pass2
      if [ "$pass1" != "$pass2" ];then
         echo "The password input is not the same, please re-enter"
         continue
      fi
    echo "$pass2" | passwd --stdin $name
    if [ $? = '0' ];then
      echo -e "${info} Create a password for $name success"
    else
      echo -e "${error} Failed to create a password for $name"
      exit
    fi
    break
  done
  sleep 1
}

add_sysuser_sudo(){
  #add visudo
  echo -e "${info} Add user to sudoers file"
  [ ! -f /etc/sudoers.back ] && \cp /etc/sudoers /etc/sudoers.back
  SUDO=`grep -w "$name" /etc/sudoers |wc -l`
  if [ $SUDO -eq 0 ];then
      sed -i '/^root/i '${name}'  ALL=(ALL)       NOPASSWD: ALL' /etc/sudoers
      sleep 1
  fi
  [ ! -z `grep -ow "$name" /etc/sudoers` ] && action "创建用户$name并将其加入visudo"  /bin/true
}

add_sysuser_sftp(){
  #set sftp homedir
  echo -e "${info} Please enter sftp home directory"
  read -p "(default:/data/${name}/sftp)" sftp_dir
  if [[ ${sftp_dir} = '' ]];then
    sftp_dir="/data/${name}/sftp"
  fi
  if [[ ! -d ${sftp_dir} ]];then
    mkdir -p ${sftp_dir}
  fi
  #父目录
  dname=$(dirname ${sftp_dir})
  groupadd sftp_users>/dev/null 2>&1
  usermod -G sftp_users -d ${dname} -s /sbin/nologin ${name}>/dev/null 2>&1
  chown -R ${name}.sftp_users ${sftp_dir}
  sed -i 's[^Subsystem.*sftp.*/usr/libexec/openssh/sftp-server[#Subsystem	sftp	/usr/libexec/openssh/sftp-server[' /etc/ssh/sshd_config
  if [[ -z `grep -E '^ForceCommand    internal-sftp' /etc/ssh/sshd_config` ]];then
		cat >>/etc/ssh/sshd_config<<EOF
Subsystem       sftp    internal-sftp
Match Group sftp_users
ChrootDirectory %h
ForceCommand    internal-sftp
EOF
  fi
}

zabbix_set(){
	output_option "请选择要安装的模块" "zabbix-server zabbix-agent zabbix-java zabbix-proxy" "install_module"
	install_module_value=(${output_value[@]})
	module_configure=$(echo ${install_module_value[@]} | sed s/zabbix/--enable/g)
	if [[ ${install_module[@]} =~ 'zabbix-server' ]];then
		diy_echo "现在设置zabbix-server相关配置" "${yellow}" "${info}"
		input_option "请输入要连接的数据库地址" "127.0.0.1" "zabbix_db_host"
		zabbix_db_host=${input_value}
		input_option "请输入要连接的数据库端口" "3306" "zabbix_db_port"
		input_option "请输入要连接的数据库名" "zabbix" "zabbix_db_name"
		zabbix_db_name=${input_value}
		input_option "请输入要连接的数据库用户" "root" "zabbix_db_user"
		zabbix_db_user=${input_value}
		input_option "请输入要连接的数据库密码" "123456" "zabbix_db_passwd"
		zabbix_db_passwd=${input_value}
	fi
	if [[ ${install_module[@]} =~ 'zabbix-agent' ]];then
		diy_echo "现在设置zabbix-agent相关配置" "${yellow}" "${info}"
		input_option "请输入要连接的zabbix-server地址" "127.0.0.1" "zabbix_server_host"
		zabbix_server_host=${input_value}
		input_option "请设置zabbix-agent的主机名地址" "zabbix_server" "zabbix_agent_host_name"
		zabbix_agent_host_name=${input_value}
	fi
	if [[ ${install_module[@]} =~ 'zabbix-java' ]];then
		echo
	fi
}

zabbix_install(){

	diy_echo "正在安装编译工具及库文件..." "" "${info}"
	yum -y install net-snmp-devel libxml2-devel libcurl-devel mysql-devel libevent-devel
	cd ${tar_dir}
	./configure --prefix=${home_dir} ${module_configure} --with-mysql --with-net-snmp --with-libcurl --with-libxml2
	make && make install
	if [ $? = '0' ];then
		diy_echo "编译完成..." "" "${info}"
	else
		diy_echo "编译失败!" "" "${error}"
		exit 1
	fi

}

zabbix_config(){

	groupadd zabbix >/dev/null 2>&1
	useradd zabbix -M -g zabbix -s /bin/false >/dev/null 2>&1
	mkdir -p ${home_dir}/logs
	chown -R zabbix.zabbix ${home_dir}/logs
	if [[ ${install_module[@]} =~ 'zabbix-server' ]];then
	
		sed -i 's#^LogFile.*#LogFile='${home_dir}'/logs/zabbix_server.log#' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# PidFile=.*@PidFile='${home_dir}'/logs/zabbix_server.pid@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# DBHost=.*@DBHost='${zabbix_db_host}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^DBName=.*@DBName='${zabbix_db_name}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^DBUser=.*@DBUser='${zabbix_db_user}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# DBPassword=.*@DBPassword='${zabbix_db_passwd}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# DBPort=.*@DBPort='${zabbix_db_port}'@' ${home_dir}/etc/zabbix_server.conf
		sed -i 's@^# Include=/usr/local/etc/zabbix_server.conf.d/\*\.conf@Include='${home_dir}'/etc/zabbix_server.conf.d/*.conf@' ${home_dir}/etc/zabbix_server.conf
	fi
 
	if [[ ${install_module[@]} =~ 'zabbix-agent' ]];then

		sed -i 's@^# PidFile=.*@PidFile='${home_dir}'/logs/zabbix_agentd.pid@' ${home_dir}/etc/zabbix_agentd.conf
		sed -i 's#^LogFile.*#LogFile='${home_dir}'/logs/zabbix_agentd.log#' ${home_dir}/etc/zabbix_agentd.conf
		sed -i 's#^Server=.*#Server='${zabbix_server_host}'#' ${home_dir}/etc/zabbix_agentd.conf
		sed -i 's#^Hostname=.*#Hostname='${zabbix_agent_host_name}'#' ${home_dir}/etc/zabbix_agentd.conf
		sed -i 's@^# Include=/usr/local/etc/zabbix_agentd.conf.d/\*\.conf@Include='${home_dir}'/etc/zabbix_agentd.conf.d/*.conf@' ${home_dir}/etc/zabbix_agentd.conf
	fi
	if [[ ${install_module[@]} =~ 'zabbix-java' ]];then
		sed -i 's@^PID_FILE=.*@PID_FILE='${home_dir}'/logs/zabbix_java.pid@' ${home_dir}/sbin/zabbix_java/settings.sh
		sed -i 's@/tmp/zabbix_java.log@'${home_dir}'/logs/zabbix_java.log@' ${home_dir}/sbin/zabbix_java/lib/logback.xml
	fi

}

add_zabbix_service(){
	Type="forking"
	if [[ ${install_module[@]} =~ 'zabbix-server' ]];then
		Environment="CONFFILE=${home_dir}/etc/zabbix_server.conf"
		PIDFile="${home_dir}/logs/zabbix_server.pid"
		ExecStart="${home_dir}/sbin/zabbix_server -c \$CONFFILE"
		conf_system_service
		add_system_service zabbix-serverd ${home_dir}/init
	fi
	if [[ ${install_module[@]} =~ 'zabbix-agent' ]];then
		Environment="CONFFILE=${home_dir}/etc/zabbix_agentd.conf"
		PIDFile="${home_dir}/logs/zabbix_agentd.pid"
		ExecStart="${home_dir}/sbin/zabbix_agentd -c \$CONFFILE"
		conf_system_service
		add_system_service zabbix-agentd ${home_dir}/init
	fi
	if [[ ${install_module[@]} =~ 'zabbix-java' ]];then
		PIDFile="${home_dir}/logs/zabbix_java.pid"
		ExecStart="${home_dir}/sbin/zabbix_java/startup.sh"
		conf_system_service
		add_system_service zabbix-java-gateway ${home_dir}/init
	fi
}

zabbix_install_ctl(){

	install_version zabbix
	install_selcet
	zabbix_set
	install_dir_set
	download_unzip
	zabbix_install
	zabbix_config
	add_zabbix_service
	clear_install

}

update_kernel(){
	diy_echo 'Updating kernel is risky. Please backup information.' "${red}"
	echo -e "${info} The current kernel version is ${kel}"
	echo -e "${info} press any key to continue"
	read
	output_option '选择升级kernel类型' '长期维护版 最新版' 'kernel_type'
	if [ ! -f /etc/yum.repos.d/elrepo.repo ]; then
		rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
		if (( ${os_release} < '7' ));then
			rpm -Uvh http://www.elrepo.org/elrepo-release-6-8.el6.elrepo.noarch.rpm
		elif (( ${os_release} >= '7' ));then
			rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
		fi
	fi
		
	if [ ! -f /etc/yum.repos.d/elrepo.repo ]; then
		echo -e "${error} Install elrepo failed, please check it."
		exit 1
	fi
	if [[ ${kernel_type} = '1' ]];then
		yum --enablerepo=elrepo-kernel install  -y kernel-lt kernel-lt-devel
	else
		yum --enablerepo=elrepo-kernel install  -y kernel-ml kernel-ml-devel
	fi
	if [[ $? != '0' ]];then
		echo -e "${error} Failed to install kernel, please check it"
		exit 1
	fi
	if (( ${os_release} < '7' ));then
		if [ ! -f "/boot/grub/grub.conf" ]; then
			echo -e "${error} /boot/grub/grub.conf not found, please check it."
			exit 1
		fi
		sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
	elif (( ${os_release} >= '7' ));then
		if [ ! -f "/boot/grub2/grub.cfg" ]; then
			echo -e "${error} /boot/grub2/grub.cfg not found, please check it."
			exit 1
		fi
		grub2-set-default 0
	fi
	echo -e "${info} The system needs to reboot."
    read -p "Do you want to restart system? [y/n]" is_reboot
    if [[ ${is_reboot} = "y" || ${is_reboot} = "Y" ]]; then
        reboot
    else
        echo -e "${info} Reboot has been canceled..."
        exit 0
    fi
}

wireguard_install(){
	if [[ ${os_release} < '7' ]];then
		echo -e "${error} wireguard只支持Centos7"
		exit 1
	fi

	system_optimize_yum
	cat > /etc/yum.repos.d/wireguard.repo <<-EOF
	[jdoss-wireguard]
	name=Copr repo for wireguard owned by jdoss
	baseurl=https://copr-be.cloud.fedoraproject.org/results/jdoss/wireguard/epel-7-$basearch/
	type=rpm-md
	skip_if_unavailable=True
	gpgcheck=1
	gpgkey=https://copr-be.cloud.fedoraproject.org/results/jdoss/wireguard/pubkey.gpg
	repo_gpgcheck=0
	enabled=1
	enabled_metadata=1
	EOF
	yum install -y dkms gcc-c++ gcc-gfortran glibc-headers glibc-devel libquadmath-devel libtool systemtap systemtap-devel iptables-services wireguard-dkms wireguard-tools
	if [[ $? = '0' ]];then
		echo -e "${info} wireguard安装成功"
	else
		echo -e "${error} wireguard安装失败"
		exit 2
	fi
}

wireguard_config(){
	mkdir /etc/wireguard
	cd /etc/wireguard
	wg genkey | tee sprivatekey | wg pubkey > spublickey
	wg genkey | tee cprivatekey | wg pubkey > cpublickey
	s1=$(cat sprivatekey)
	s2=$(cat spublickey)
	c1=$(cat cprivatekey)
	c2=$(cat cpublickey)
	get_public_ip
	get_net_name
	cat > /etc/wireguard/wg0.conf <<-EOF
	[Interface]
	PrivateKey = $s1
	Address = 10.0.0.1/24 
	PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${net_name} -j MASQUERADE
	PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${net_name} -j MASQUERADE
	ListenPort = 10111
	DNS = 8.8.8.8
	MTU = 1420

	[Peer]
	PublicKey = $c2
	AllowedIPs = 10.0.0.2/32
	EOF
	cat > /etc/wireguard/client.conf <<-EOF
	[Interface]
	PrivateKey = $c1
	Address = 10.0.0.2/24 
	DNS = 8.8.8.8
	MTU = 1420

	[Peer]
	PublicKey = $s2
	Endpoint = $public_ip:10111
	AllowedIPs = 0.0.0.0/0, ::0/0
	PersistentKeepalive = 25
	EOF

	ip_forward=$(cat /etc/sysctl.conf | grep 'net.ipv4.ip_forward = 1')
	if [[ -z ${ip_forward} ]];then
		echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
		sysctl.conf -p > /dev/null
	fi
	systemctl start wg-quick@wg0
	if [[ -n $(ip a | grep -Eo '^wg0') ]];then
		echo -e "${info} wireguard启动成功，请下载/etc/wireguard/client.conf客户端配置文件"
	else
		echo -e "${info} wireguard启动失败"
	fi
}

wireguard_order(){
	wireguard_install
	wireguard_config
	service_control wg-quick@wg0
}

add_log_cut(){
	#$1配置文件名 $2日志文件路径
	conf_name=$1
	logs_dir=$2
	cat >/etc/logrotate.d/${conf_name}<<-EOF
	${logs_dir}{
	daily
	rotate 15
	missingok
	notifempty
	copytruncate
	dateext
	}
	EOF

}

conf_system_service(){
#必传参数ExecStart
	if [[ "${os_release}" -lt 7 ]]; then
		cat >${home_dir}/init<<-EOF
		#!/bin/bash
		# chkconfig: 345 70 60
		# description: ${soft_name} daemon
		# processname: ${soft_name}

		EnvironmentFile="${EnvironmentFile:-}"
		Environment="${Environment:-}"
		Name="${Name:-${soft_name}}"
		Home="${Home:-${home_dir}}"
		PidFile="${PidFile:-}"
		User="${User:-root}"
		ExecStart="${ExecStart:-}"
		ARGS="${ARGS:-}"
		ExecStop="${ExecStop:-}"
		EOF
		cat >>${home_dir}/init<<-'EOF'
		#EUV
		[[ -f ${EnvironmentFile} ]] && . ${EnvironmentFile}
		[[ -f ${Environment} ]] && export ${Environment}
		_pid(){
		  [[ -s $PidFile ]] && pid=$(cat $PidFile) && kill -0 $pid 2>/dev/null || pid=''
		  [[ -z $PidFile ]] && pid=$(ps aux | grep ${Home} | grep -v grep | awk '{print $2}')
		}

		_start(){
		  _pid
		  if [ -n "$pid" ];then
		    echo -e "\e[00;32m${Name} is running with pid: $pid\e[00m"
		  else
		    echo -e "\e[00;32mStarting ${Name}\e[00m"
		    id -u ${User} >/dev/null
		    if [ $? = 0 ];then
		      su ${User} -c "${ExecStart} ${ARGS} &"
		    fi
		    _status
		  fi
		}

		_stop(){
		  _pid
		  if [ -n "$pid" ]; then
		    [[ -n "${ExecStop}" ]] && ${ExecStop}
		    [[ -z "${ExecStop}" ]] && kill $pid
		    for ((i=1;i<=5;i++));
		    do
		      _pid
		      if [ -n "$pid" ]; then
		        echo -n -e "\e[00;31mWaiting for the program to exit\e[00m\n";
		        sleep 3
		      else
		        echo -e "\e[00;32m${Name} stopped successfully\e[00m" && break
		      fi
		    done
		    _pid
		    if [ -n "$pid" ]; then
		        kill -9 $pid && echo -e "\033[0;33m${Name} process is being forced to shutdown...(pid:$pid)\e[00m"
		    fi
		  else
		    echo -e "\e[00;31m${Name} is not running\e[00m"
		  fi
		}

		_status(){
		  _pid
		  if [ -n "$pid" ]; then
		    echo -e "\e[00;32m${Name} is running with pid: $pid\e[00m"
		  else 
		    echo -e "\e[00;31m${Name} is not running\e[00m"
		  fi
		}
		_usage(){
		  echo -e "Usage: $0 {\e[00;32mstart\e[00m|\e[00;31mstop\e[00m|\e[00;32mstatus\e[00m|\e[00;31mrestart\e[00m}"
		}
		case $1 in
		    start)
		    _start
		    ;;
		    stop)
		    _stop
		    ;;   
		    restart)
		    _stop
		    sleep 3
		    _start
		    ;;
		    status)
		    _status
		    ;;
		    *)
		    _usage
		    ;;
		esac
		EOF
	elif [[ "${os_release}" -ge 7 ]]; then
		cat >${home_dir}/init<<-EOF
		[Unit]
		Description=${soft_name}
		After=syslog.target network.target

		[Service]
		Type=${Type:-simple}
		User=${User:-root}

		EnvironmentFile=${EnvironmentFile:-}
		Environment=${Environment:-}

		WorkingDirectory=${WorkingDirectory:-}
		ExecStart=${ExecStart:-} ${ARGS:-}
		ExecReload=${ExecReload:-/bin/kill -s HUP \$MAINPID}
		ExecStop=${ExecStop:-/bin/kill -s QUIT \$MAINPID}
		TimeoutStopSec=5
		Restart=${Restart:-on-failure}
		[Install]
		WantedBy=multi-user.target
		EOF
	fi
	#删除空值
	[[ -z ${WorkingDirectory} ]] && sed -i /WorkingDirectory=/d ${home_dir}/init
	[[ -z ${Environment} ]] && sed -i /Environment=/d ${home_dir}/init
	[[ -z ${EnvironmentFile} ]] && sed -i /EnvironmentFile=/d ${home_dir}/init
}

add_system_service(){
	#$1服务名 $2服务文件路径 $3现在启动
	service_name=$1
	service_file_dir=$2
	start_arg=$3
	if [[ "${os_release}" < '7' ]]; then
		\cp ${service_file_dir} /etc/init.d/${service_name}
	elif [[ "${os_release}" > '6' ]]; then
		\cp ${service_file_dir} /etc/systemd/system/${service_name}.service
	fi
	service_control
}

service_control(){
	if [[ "x$1" != 'x' ]];then
		service_name=$1
	fi
	if [[ ${os_release} -lt '7' ]];then
		chmod +x /etc/init.d/${service_name}
		chkconfig --add /etc/init.d/${service_name}
		echo -e "${info} ${service_name} command: $(diy_echo "service ${service_name} start|stop|restart|status" "$yellow")"
		[[ ${start_arg} = 'y' ]] && service ${service_name} start && diy_echo "${service_name}启动完成." "" "${info}"
	fi

	if [[  ${os_release} -ge '7' ]];then
		systemctl daemon-reload
		systemctl enable ${service_name} >/dev/null
		echo -e "${info} ${service_name} command: $(diy_echo "systemctl start|stop|restart|status ${service_name}" "$yellow")"
		[[ ${start_arg} = 'y' ]] && systemctl start ${service_name} && diy_echo "${service_name}启动完成." "" "${info}"
	fi
}

add_sys_env(){
 
	if [[ -n $1 ]];then
		option=($1)
		for item in ${option[@]}
		do
			cat >>/etc/profile.d/${soft_name}.sh<<-EOF
			export $item
			EOF
		done
		chmod +x /etc/profile.d/${soft_name}.sh
		source /etc/profile.d/${soft_name}.sh
	fi
	diy_echo "请再运行一次source /etc/profile" "${yellow}" "${info}"

}

multi_function_backup_script_set(){
	output_option "请选择需要备份的类型" "mysql dir svn" "back_type"
	back_type=(${output_value[@]})
	input_option "备份保留时长(天)" "90" "backup_save_time"
	input_option "备份文件存储路径" "/data/backup" "backup_home_dir"
	backup_home_dir=${input_value}
	backup_config
	if [[ ${back_type[@]} =~ 'mysql' ]];then
		mysql_backup_set
	fi
	if [[ ${back_type[@]} =~ 'dir' ]];then
		dir_backup_set
	fi
	if [[ ${back_type[@]} =~ 'svn' ]];then
		svn_backup_set
	fi
}

mysql_backup_set(){
	diy_echo "此备份脚本可以备份多个MySQL主机分别备份不同的库" "" "${info}"
	input_option "请输入要备份MySQL主机的个数" "1" "mysql_num"
	if [[ ${mysql_num} > 1 ]];then
		input_option '请依次输入mysql连接ip' '192.168.1.2 192.168.1.3' 'mysql_ip'
		mysql_ip=(${input_value[@]})
		input_option '请依次输入mysql连接端口' '3306 3307' 'mysql_port'
		input_option '请依次输入mysql连接用户名' 'root user' 'mysql_user'
		mysql_user=(${input_value[@]})
		input_option '请依次输入mysql连接密码' '123456 654321' 'mysql_passwd'
		mysql_passwd=(${input_value[@]})
		input_option '请依次输入所有要备份的库名' 'mysql test' 'db_name'
		db_name=(${input_value[@]})
		input_option '请依次输入每个主机备份库的个数' '1 1' 'mysql_db_num'
		mysql_db_num=(${input_value[@]})
	else
		input_option "请输入mysql连接ip" "192.168.1.2" "mysql_ip"
		mysql_ip=${input_value}
		input_option "请输入mysql连接端口" "3306" "mysql_port"
		input_option "请输入mysql连接用户名" "root" "mysql_user"
		mysql_user=${input_value}
		input_option "请输入mysql连接密码" "123456" "mysql_passwd"
		mysql_passwd=${input_value}
		input_option "请输入所有要备份的库名" "mysql" "db_name"
		db_name=(${input_value[@]})
		mysql_db_num=${#db_name[@]}
	fi
	sed -i "s#enable_backup_db=0#enable_backup_db=1#" ./multi_function_backup_script.sh
	sed -i "s#mysql_user=()#mysql_user=(${mysql_user[@]})#" ./multi_function_backup_script.sh
	sed -i "s#mysql_passwd=()#mysql_passwd=(${mysql_passwd[@]})#" ./multi_function_backup_script.sh
	sed -i "s#mysql_ip=()#mysql_ip=(${mysql_ip[@]})#" ./multi_function_backup_script.sh
	sed -i "s#mysql_port=()#mysql_port=(${mysql_port[@]})#" ./multi_function_backup_script.sh
	sed -i "s#mysql_db_num=()#mysql_db_num=(${mysql_db_num[@]})#" ./multi_function_backup_script.sh
	sed -i "s#db_name=()#db_name=(${db_name[@]})#" ./multi_function_backup_script.sh
}

dir_backup_set(){
	diy_echo "此备份脚本可以备份多个目录" "" "${info}"
	input_option "请输入要备份的目录" "/data/ftp /data/file" "backup_dir"
	backup_dir=(${input_value[@]})
	sed -i "s#enable_backup_dir=0#enable_backup_dir=1#" ./multi_function_backup_script.sh
	sed -i "s#backup_dir=()#backup_dir=(${backup_dir[@]})#" ./multi_function_backup_script.sh
}

svn_backup_set(){
	input_option "请输入要备份的目录" "/data/svn" "svn_project_dir"
	svn_project_dir=${input_value}
	output_option "请选择备份方案" "全量备份 全量备份+增量备份 固定版本步长备份" "svn_back_type"
	sed -i "s#enable_backup_svn=0#enable_backup_svn=1#" ./multi_function_backup_script.sh
	sed -i "s#svn_project_dir=.*#svn_project_dir="${svn_project_dir}"#" ./multi_function_backup_script.sh	

	if [[ ${svn_back_type} = 1 ]];then
		sed -i "s#svn_full_back='0'#svn_full_back='1'#" ./multi_function_backup_script.sh
	elif [[ ${svn_back_type} = 2 ]];then
		input_option "请输入要全量备份周期(天)" "7" "svn_back_cycle"
		sed -i "s#svn_full_back='0'#svn_full_back='1'#" ./multi_function_backup_script.sh
		sed -i "s#svn_incremental_back='0'#svn_incremental_back='1'#" ./multi_function_backup_script.sh
		sed -i "s#svn_back_cycle='7'#svn_back_cycle="${svn_back_cycle}"#" ./multi_function_backup_script.sh
	elif [[ ${svn_back_type} = 3 ]];then
		input_option "请输入要备份版本号步长值" "500" "svn_back_size"
		sed -i "s#svn_fixed_ver_back='0'#svn_fixed_ver_back='1'#" ./multi_function_backup_script.sh
		sed -i "s#svn_back_size='1000'#svn_back_size="${svn_back_size}"#" ./multi_function_backup_script.sh
	fi

}

backup_config(){
	cat >multi_function_backup_script.sh<<'ACC'
#!/bin/bash
#多功能备份脚本
#2019.2

#本地备份存放目录
backup_home_dir=/data/backup
#备份日志
log_dir=/data/backup/bak.log
#工程名
project_name='my-web'
#备份保留时长(天)
backup_save_time='90'

enable_ftp='0'
ftp_host='127.0.0.1'
ftp_port='21'
ftp_username='admin'
ftp_password='admin'
ftp_dir='/backup'

enable_backup_dir=0
#需要备份的目录
backup_dir=(/data/ftp /data/file)

enable_backup_db=0
#数据库用户密码ip端口必须一一对应
mysql_user=()
mysql_passwd=()
mysql_ip=()
mysql_port=()
#每个mysql主机需要备份库的个数
mysql_db_num=()
#需要备份的数据库按顺序添加
db_name=()

enable_backup_svn=0
#需要备份的目录
svn_project_dir=
#备份方案
#全量备份
svn_full_back='0'
#增量备份
svn_incremental_back='0'
svn_back_cycle='7'
#固定版本步长备份
svn_fixed_ver_back='0'
svn_back_size='1000'

backup_sql(){

today_back_name="${project_name}-db-${db_name[$k]}-$(date +%Y%m%d)"
old_back_name="${project_name}-db-${db_name[$k]}-$(date -d "${backup_save_time} days ago" +%Y%m%d)"

${mysqldump} -u${mysql_user[$i]} -p${mysql_passwd[$i]} -h${mysql_ip[$i]} -P${mysql_port[$i]} ${db_name[$k]} --log-error=${log_dir} > ${today_back_name}.sql
if [ $? = "0" ];then
	tar zcf ${today_back_name}.sql.tar.gz -C ${backup_home_dir} ${today_back_name}.sql && rm -rf ${today_back_name}.sql
	echo -e "打包${today_back_name}文件成功">>${log_dir}
	rm -rf ${old_back_name}.sql.tar.gz && echo "删除本地${old_back_name}.sql.tar.gz完成">>${log_dir}
	[ ${enable_ftp} = 0 ] && ftp_control ${today_back_name}.sql.tar.gz ${old_back_name}.sql.tar.gz
fi

}

backup_dir(){

if [[ -d $1 ]];then
	backup_path=$1
	dir_name=`echo ${backup_path##*/}`
	pre_dir=`echo ${backup_path}|sed 's/'${dir_name}'//g'`
	today_dir_gz="${project_name}-dir-${dir_name}-$(date +"%Y%m%d")"
	old_dir_gz="${project_name}-dir-${dir_name}-$(date -d "${backup_save_time} days ago" +%Y%m%d)"
    
	tar zcf ${today_dir_gz}.tar.gz -C ${pre_dir} ${dir_name}.tar.gz>>${log_dir} 2>&1
	if [ $? = "0" ];then	
		echo "打包${today_dir_gz}.tar.gz文件成功">>${log_dir}
		rm -rf ${old_dir_gz}.tar.gz && echo "删除本地${old_dir_gz}.tar.gz完成">>${log_dir}
		[ ${enable_ftp} = 0 ] && ftp_control ${today_dir_gz}.tar.gz ${old_dir_gz}.tar.gz
	fi
else
	echo "不存在$1文件夹">>${log_dir}
fi

}

backup_svn(){

today_back_name="${project_name}-svn-$(date +%Y%m%d)"
old_back_name="${project_name}-svn-$(date -d "${backup_save_time} days ago" +%Y%m%d)"

_full_back(){

svnadmin dump ${svn_project_dir} >${backup_home_dir}/${today_back_name}.full.dump
if [[ $? = 0 ]];then
	tar zcf ${today_back_name}.full.dump.tar.gz -C ${backup_home_dir} ${today_back_name}.full.dump
	rm -rf ${today_back_name}.full.dump ${old_back_name}.full.dump.tar.gz
fi
}

_incremental_back(){

svnadmin dump ${svn_project_dir} -r ${svn_last_ver}:HEAD --incremental >${backup_home_dir}/${today_back_name}.${svn_last_ver}-HEAD.dump
if [[ $? = 0 ]];then
	tar zcf ${today_back_name}.${svn_last_ver}-HEAD.dump.tar.gz -C ${backup_home_dir} ${today_back_name}.${svn_last_ver}-HEAD.dump
	rm -rf ${today_back_name}.*HEAD.dump ${old_back_name}.*HEAD.dump.tar.gz
fi
}

_fixed_ver_back(){

svnadmin dump ${svn_project_dir} -r ${svn_old_ver}:${svn_last_ver} >${backup_home_dir}/${today_back_name}.${svn_old_ver}-${svn_last_ver}.dump
if [[ $? = 0 ]];then
	tar zcf ${today_back_name}.${svn_old_ver}-${svn_last_ver}.dump.tar.gz -C ${backup_home_dir} ${today_back_name}.${svn_old_ver}-${svn_last_ver}.dump
	rm -rf ${today_back_name}.${svn_old_ver}-${svn_last_ver}.dump
	ls ${backup_home_dir} | grep -oE "${old_back_name}.[0-9]{1,}-[0-9]{1,}.dump.tar.gz" | xargs rm -rf
fi
}

#全量备份
if [[ ${svn_full_back} = 1 && ${svn_incremental_back} = 0 ]];then
	_full_back
fi
#全量备份加增量
if [[ ${svn_full_back} = 1 && ${svn_incremental_back} = 1 ]];then
	if [[ -f ${backup_home_dir}/${project_name}-svn-$(date -d "${svn_back_cycle} days ago" +%Y%m%d).full.dump.tar.gz ]];then
		svn_last_ver=$(svnlook youngest ${svn_project_dir}) && echo ${svn_last_ver}>/tmp/svn_last_ver.txt
		_full_back
	elif [[ ! -f /tmp/svn_last_ver.txt ]];then
		svn_last_ver=$(svnlook youngest ${svn_project_dir}) && echo ${svn_last_ver}>/tmp/svn_last_ver.txt
		_full_back
	else
		svn_last_ver=$(cat /tmp/svn_last_ver.txt)
		_incremental_back
	fi
fi
#固定版本步长
if [[ ${svn_fixed_ver_back} = 1 ]];then
	svn_last_ver=$(svnlook youngest ${svn_project_dir})
	svn_old_ver=$(((${svn_last_ver}-${svn_back_size})))
	[[ ${svn_old_ver} < 0 ]] && svn_old_ver=0
	_fixed_ver_back
fi
}

backup_sql_control(){
#外循环次数控制
num=$(expr ${#mysql_user[@]} - 1)
mysqldump --help>/dev/null 2>&1
if [ $? = 0 ];then
	mysqldump='mysqldump'
else
	mysqldump=$(find / -name mysqldump | grep -ei .*/mysql.*/bin/mysqldump)
fi

k=0
q=0
for((i=0;i<=${num};i++))
do		
	for((j=1;j<=${mysql_db_num[$q]};j++))
	do
	backup_sql
	#内循环内按顺取${db_name}数据库
	k=`expr $k + 1`
	done
	#外循环内按顺取${mysql_db_num}控制内循环的次数
	q=`expr $q + 1`
done
}

backup_dir_control(){

for dd in ${backup_dir[@]}
do
	backup_dir ${dd}
done
}

ftp_control(){

echo "正在上传文件$1">>${log_dir}
cd ${backup_home_dir}
lftp ${ftp_host} -u ${ftp_username},${ftp_password} <<-EOF
cd ${ftp_dir}
put ${1}
bye
EOF
if [ $? = '0' ];then
	echo "文件$1上传完成">>${log_dir}
	lftp ${ftp_host} -u ${ftp_username},${ftp_password} <<-EOF
	cd ${ftp_dir}
	rm ${2}
	bye
	EOF
	if [ $? = 0 ];then
		echo "成功删除ftp文件$2">>${log_dir}
	fi
else
	echo "文件$1上传失败">>${log_dir}
fi
}

[ ! -d ${backup_home_dir} ] && mkdir -p ${backup_home_dir}
cd ${backup_home_dir}
echo "开始时间:$(date +%y-%m-%d-%H:%M:%S)">>${log_dir}

[[ ${enable_backup_db} = 1 ]] && backup_sql_control
[[ ${enable_backup_dir} = 1 ]] && backup_dir_control
[[ ${enable_backup_svn} = 1 ]] && backup_svn >>${log_dir} 2>&1

echo -e "结束时间:$(date +%y-%m-%d-%H:%M:%S)\n">>${log_dir}
ACC
	sed -i "s#^backup_home_dir=/data/backup#backup_home_dir=${backup_home_dir}#" ./multi_function_backup_script.sh
	sed -i "s#^log_dir=.*#log_dir=${backup_home_dir}/bakup.log#" ./multi_function_backup_script.sh
	sed -i "s#^backup_save_time='90'#backup_save_time=${backup_save_time}#" ./multi_function_backup_script.sh

}

mysql_tool(){
output_option 'MySQL常用脚本' '添加MySQL备份脚本  找回MySQLroot密码 ' 'num'

case "$num" in
	1)multi_function_backup_script_set
	;;
	2)reset_mysql_passwd
	;;
esac
}

basic_environment(){

output_option '请选择要安装的环境' 'JDK PHP Ruby Nodejs' 'num'
case "$num" in
	1)java_install_ctl
	;;
	2)php_install_ctl
	;;
	3)ruby_install_ctl
	;;
	4)node_install_ctl
	;;
esac
}

web_services(){

output_option '请选择要安装的软件' 'Nginx Tomcat' 'num'
case "$num" in
	1)nginx_install_ctl
	;;
	2)tomcat_install_ctl
	;;
esac
}

database_services(){

output_option '请选择要安装的软件' 'MySQL mongodb Redis Memcached' 'num'
case "$num" in
	1)mysql_install_ctl
	;;
	2)mongodb_inistall_ctl
	;;
	3)redis_install_ctl
	;;
	4)memcached_inistall_ctl
	;;
esac
}

middleware_services(){

output_option '请选择要安装的软件' 'ActiveMQ RocketMQ Zookeeper Kafka' 'num'
case "$num" in
	1)activemq_install_ctl
	;;
	2)rocketmq_install_ctl
	;;
	3)zookeeper_install_ctl
	;;
	4)kafka_install_ctl
	;;
esac
}

storage_service(){

output_option '请选择要安装的软件' 'FTP SFTP 对象存储服务(OSS/minio) FastDFS NFS' 'num'
case "$num" in
	1)ftp_install_ctl
	;;
	2)add_sysuser && add_sysuser_sftp
	;;
	3)minio_install_ctl
	;;
	4)fastdfs_install_ctl
	;;
	5)nfs_install_ctl
	;;
esac
}

operation_platform(){
output_option '请选择要安装的平台' 'K8S系统 ELK日志平台 Zabbix监控 Rancher平台(k8s集群管理)' 'platform'
case "$platform" in
	1)k8s_install_ctl
	;;
	2)elk_install_ctl
	;;
	3)zabbix_install_ctl
	;;
esac

}

tools(){
output_option '请选择进行的操作' '优化系统配置 查看系统详情 升级内核版本 创建用户并将其加入visudo 安装WireGuard-VPN 多功能备份脚本 主机ssh互信' 'tool'

case "$tool" in
	1)system_optimize_set
	;;
	2)sys_info_detail
	;;
	3)update_kernel
	;;
	4)add_sysuser && add_sysuser_sudo
	;;
	5)wireguard_order
	;;
	6)multi_function_backup_script_set
	;;
	7)auto_ssh_keygen
	;;
esac
}

main(){

output_option '请选择需要安装的服务' '基础环境 WEB服务 数据库服务 中间件服务 存储服务 运维平台 MySQL工具箱 运维工具箱' 'mian'

case "$mian" in
	1)basic_environment
	;;
	2)web_services
	;;
	3)database_services
	;;
	4)middleware_services
	;;
	5)storage_service
	;;
	6)operation_platform
	;;
	7)mysql_tool
	;;
	8)tools
	;;
esac
}

clear
[[ $EUID -ne 0 ]] && echo -e "${error} Need to use root account to run this script!" && exit 1
echo -e "+ + + + + + + + + + + + + + + + + + + + + + + + + +"
echo -e "+ System Required: Centos 6+                      +"
echo -e "+ Description: Multi-function one-click script    +"
echo -e	"+                                                 +"
echo -e "+                                   Version: 2.1  +"
echo -e "+                                 by---wang2017.7 +"
echo -e "+ + + + + + + + + + + + + + + + + + + + + + + + + +"
colour_keyword
sys_info
main

