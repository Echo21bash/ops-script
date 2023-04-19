#!/bin/bash
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