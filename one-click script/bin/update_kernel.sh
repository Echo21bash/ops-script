#!/bin/bash
#yum升级内核
. ./public.sh
update_kernel(){
	diy_echo '升级内核又很小几率升级失败，请备份重要文件。' "${yellow}" "${warning}"
	diy_echo "当前内核版本是：${kel}" "${info}"
	diy_echo "按任意键继续" "${info}"
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
		diy_echo "添加elrepo源失败, 请检查" "${error}"
		exit 1
	fi
	if [[ ${kernel_type} = '1' ]];then
		yum --enablerepo=elrepo-kernel install  -y kernel-lt kernel-lt-devel
	else
		yum --enablerepo=elrepo-kernel install  -y kernel-ml kernel-ml-devel
	fi
	if [[ $? != '0' ]];then
		diy_echo "安装内核失败, 请检查" "${red}" "${error}"
		exit 1
	fi
	if (( ${os_release} < '7' ));then
		if [ -f "/boot/grub/grub.conf" ]; then
			sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
		else
			diy_echo "文件/boot/grub/grub.conf 不存在, 请检查" "${red}" "${error}"
			exit 1
		fi
		
	elif (( ${os_release} >= '7' ));then
		if [ -f "/boot/grub2/grub.cfg" ]; then
			grub2-set-default 0
		else
			diy_echo "文件/boot/grub2/grub.cfg 不存在, 请检查" "${red}" "${error}"
			exit 1
		fi
		grub2-set-default 0
	fi
	diy_echo "系统内核升级完成,系统需要重启.." "${info}"
	input_option "是否重启系统？" "n"
	is_reboot=${input_value}
    if [[ ${is_reboot} = "y" || ${is_reboot} = "Y" ]]; then
        reboot
    else
		diy_echo "取消重启.." "${info}"
        exit 0
    fi
}
colour_keyword
sys_info
update_kernel
