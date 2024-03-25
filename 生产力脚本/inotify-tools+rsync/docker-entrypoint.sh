#!/bin/bash
RUN_MODE=${RUN_MODE:-sersync}
#rsync认证用户
RSYNCD_USER=${RSYNCD_USER:-rsync}
#rsync认证密码
RSYNCD_PASSWD=${RSYNCD_PASSWD:-Ki13W@yYZvbJ}
#SSH认证密码开启SFTP
SSH_PASSWD=${SSH_PASSWD:-}
#rsyncd模块名称
RSYNCD_MOD_NAME=${RSYNCD_MOD_NAME:-data}
#rsyncd存储目录
RSYNCD_PATH=${RSYNCD_PATH:-/data}
#rsyncd最大连接数
RSYNCD_MAX_CONN=${RSYNCD_MAX_CONN:-300}
#rsyncd白名单
RSYNCD_HOSTS_ALLOW=${RSYNCD_HOSTS_ALLOW:-0.0.0.0/0}
#使用配置文件
USE_CONF_FILE=${USE_CONF_FILE:-0}

if [[ ${RUN_MODE} = 'rsyncd' ]];then
	if [[ ${USE_CONF_FILE} = '0' ]];then
		cat > /etc/rsyncd.conf <<-EOF
		uid = root
		gid = root
		port = 873
		secrets file = /etc/rsyncd.secret
		ignore errors = yes
		reverse lookup = no
		log file = /dev/stdout
		max connections = ${RSYNCD_MAX_CONN}
		[${RSYNCD_MOD_NAME}]
		hosts allow = ${RSYNCD_HOSTS_ALLOW}
		read only = false
		path = ${RSYNCD_PATH}
		comment = ${RSYNCD_PATH} directory
		auth users = ${RSYNCD_USER}
		EOF
		echo "${RSYNCD_USER}:${RSYNCD_PASSWD}" >/etc/rsyncd.secret
		[[ ! -d ${RSYNCD_PATH} ]] && mkdir -p ${RSYNCD_PATH}
	fi
	chmod  600 /etc/rsyncd.secret
	chmod  600 /etc/rsyncd.conf
	if [[ -n ${SSH_PASSWD} ]];then
		echo "root:${SSH_PASSWD}" | chpasswd
		service ssh restart
	fi
	exec "$@"
	rsync --no-detach --daemon --config /etc/rsyncd.conf
elif [[ ${RUN_MODE} = 'sersync' ]];then
	#内核参数修改
	echo 'fs.inotify.max_user_watches = 999999' >> /etc/sysctl.conf
	echo 'fs.inotify.max_user_instances = 1024' >> /etc/sysctl.conf
	echo 'fs.inotify.max_queued_events = 999999' >> /etc/sysctl.conf
	#内核参数生效
	sysctl -p
	#设置权限
	echo "${RSYNCD_PASSWD}" >/etc/rsync.passwd
	chmod 600 /etc/rsync.passwd
	#启动进程
	exec "$@"
	/usr/local/sersync/bin/inotify.sh -f /usr/local/sersync/etc/sersync.conf
fi