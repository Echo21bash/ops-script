#!/bin/bash

. ./public.sh
update_kernel(){

	diy_echo "当前内核版本是：${kel}" "${info}"
	kernel_version=`uname -a | awk '{printf $3}'`
	if [[ ! -d /lib/modules/${kernel_version}/kernel/drivers/md/bcache ]];then
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

		yum --enablerepo=elrepo-kernel install  -y kernel-lt kernel-lt-devel
		#yum --enablerepo=elrepo-kernel install  -y kernel-ml kernel-ml-devel
		if [[ $? != '0' ]];then
			diy_echo "安装内核失败, 请检查" "${red}" "${error}"
			exit 1
		fi
		if [[ ${os_release} < '7' ]];then
			if [ -f "/boot/grub/grub.conf" ]; then
				sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
			else
				diy_echo "文件/boot/grub/grub.conf 不存在, 请检查" "${red}" "${error}"
				exit 1
			fi	
		elif [[ ${os_release} > '6' ]];then
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
		fi
	fi

}

load_bcache_mod(){
	diy_echo '配置内核bcache模块' "${yellow}" "${info}"
	if [[ -d /lib/modules/${kernel_version}/kernel/drivers/md/bcache ]];then
		if [[ -d /etc/modules-load.d ]];then
			echo bcache >/etc/modules-load.d/bcache-modules.conf
		fi
		if [[ -d /etc/sysconfig/modules ]];then
			cat >/etc/sysconfig/modules/bcache.modules <<-'EOF'
			#!/bin/sh 
			/sbin/modinfo -F filename bcache > /dev/null 2>&1 
			if [ $? -eq 0 ]; then 
			    /sbin/modprobe bcache 
			fi
			EOF
			chmod 755 /etc/sysconfig/modules/bcache.modules
		fi
	fi
}


install_bcache_tools(){
	diy_echo '安装依赖和工具' "${yellow}" "${info}"
	yum install libblkid-devel -y && rpm -ivh bcache-tools-1.0.8-1.10.el7.centos.x86_64.rpm
	\cp ./bcache-status /usr/sbin && chmod +x /usr/sbin/bcache-status
}

colour_keyword
sys_info
update_kernel
load_bcache_mod
install_bcache_tools
