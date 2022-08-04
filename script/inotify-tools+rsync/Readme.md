# 脚本数据同步

## 使用说明

inotify.sh脚本为监听目录变化，支持多个目录

sersync.sh脚本为根据监听到的事件分别调用rsync进行与远程服务器(依赖rsyncd服务)进行数据增量同步，支持多个目标服务器

## 依赖安装

```shell
##Centos7
yum install epel-relase -y
yum install inotify-tools -y
yum install rsync -y
##Openeuler
yum install inotify-tools -y
yum install rsync -y
```

## 内核参数优化

```shell
echo 'fs.inotify.max_user_watches = 999999' >> /etc/sysctl.conf
echo 'fs.inotify.max_user_instances = 1024' >> /etc/sysctl.conf
echo 'fs.inotify.max_queued_events = 999999' >> /etc/sysctl.conf
sysctl -p
```

## Systemd参数优化

```shell
cat /etc/systemd/system.conf
DefaultLimitNOFILE=204800
DefaultLimitNPROC=65536
```