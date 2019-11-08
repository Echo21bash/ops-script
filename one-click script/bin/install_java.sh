#install java script
. ./public.sh
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


install_version java
install_selcet
install_dir_set
download_unzip
install_java
clear_install
