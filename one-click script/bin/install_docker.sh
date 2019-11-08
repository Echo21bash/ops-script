#install docker script
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
