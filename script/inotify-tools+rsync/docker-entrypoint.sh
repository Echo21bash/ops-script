#!/bin/bash
RUN_MODE=${RUN_MODE:-sersync}
#rsync认证用户
RSYNCD_USER=${RSYNC_USER:-rsync}
#rsync认证密码
RSYNCD_PASSWD=${RSYNC_PASSWD:-Ki13W@yYZvbJ}
#rsyncd存储目录
RSYNCD_PATH=${RSYNCD_PATH:-/data}
#rsyncd最大连接数
RSYNCD_MAX_CONN=${RSYNC_MAX_CONN:-300}
#rsyncd白名单
RSYNCD_HOSTS_ALLOW=${RSYNCD_HOSTS_ALLOW:-0.0.0.0/0}

if [[ ${RUN_MODE} = 'rsyncd' ]];then
	cat > /etc/rsyncd.conf <<EOF
uid = root
gid = root
max connections = ${RSYNCD_MAX_CONN}
port = 873
secrets file = /etc/rsync.secret
ignore errors = yes
reverse lookup = no
log file = /dev/stdout
port = 873
[volume]
hosts deny = *
hosts allow = ${RSYNCD_HOSTS_ALLOW}
read only = false
path = ${RSYNCD_PATH}
comment = ${RSYNCD_PATH} directory
auth users = ${RSYNCD_USER}
EOF
	echo "${RSYNCD_USER}:${RSYNCD_PASSWD}" >/etc/rsyncd.secret
	chmod  600 /etc/rsync.secret
	[[ ! -d ${RSYNCD_PATH} ]] && mkdir -p ${RSYNCD_PATH}
	rsync --no-detach --daemon --config /etc/rsyncd.conf
elif [[ ${RUN_MODE} = 'sersync' ]];then
	#内核参数修改
	echo 'fs.inotify.max_user_watches = 999999' >> /etc/sysctl.conf
	echo 'fs.inotify.max_user_instances = 1024' >> /etc/sysctl.conf
	echo 'fs.inotify.max_queued_events = 999999' >> /etc/sysctl.conf
	#内核参数生效
	sysctl -p
	#设置权限
	chmod 600 /etc/rsync.passwd
	#启动进程
	/usr/local/sersync/bin/inotify.sh -f /usr/local/sersync/etc/sersync.conf &
	tail -F /usr/local/sersync/logs/rsync-err.log
fi