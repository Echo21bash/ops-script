# 数据同步方案

## 同步原理

> Inotify，它是在内核 2.6.13 版本中引入的一个新功能，它为用户态监视文件系统的变化提供了强大的支持，允许监控程序打开一个独立文件描述符，并针对事件集监控一个或者多个文件，例如打开、关闭、移动/重命名、删除、创建或者改变属性。

**基于inotify监听文件事件类型，然后调用rsync进行远程同步到rsyncd服务端**

## 使用说明

### 组件部署说明

> * inotify、rsync需要部署在需要同步的服务器；
>
> * rsyncd需要部署在备份服务器用于接收客户端数据；
>
> * inotify.sh脚本用于监听目录变化并处理重复事件；
>
> * sersync.sh脚本用于根据传入的参数调用rsync与远程服务器(依赖rsyncd服务)进行数据增量同步；

### 依赖安装

* inotify-tools

```shell
##Centos7
yum install epel-relase -y
yum install inotify-tools -y
##Openeuler
yum install inotify-tools -y
```

>也可使用最新版inotify-tools编译安装

```shell
wget https://ghproxy.com/https://github.com/inotify-tools/inotify-tools/archive/refs/tags/3.22.6.0.tar.gz
tar zxf 3.22.6.0.tar.gz
cd inotify-tools-3.22.6.0/
yum install automake autoconf libtool -y
sh autogen.sh
./configure && make && make install
```

* rsync

```shell
yum install rsync -y
```

### 内核参数优化

```shell
echo 'fs.inotify.max_user_watches = 999999' >> /etc/sysctl.conf
echo 'fs.inotify.max_user_instances = 1024' >> /etc/sysctl.conf
echo 'fs.inotify.max_queued_events = 999999' >> /etc/sysctl.conf
sysctl -p
```

### systemd参数优化

```shell
cat /etc/systemd/system.conf
DefaultLimitNOFILE=204800
DefaultLimitNPROC=65536
```

### 监听脚本安装

```shell
mkdir -p /usr/local/sersync/
cp inotify.sh sersync.sh /usr/local/sersync
chmod +x /usr/local/sersync/inotify.sh
chmod +x /usr/local/sersync/sersync.sh
```

```shell
###配置守护进程
cat > /etc/systemd/system/sersync.service <<EOF
[Unit]
Description=sersync
After=syslog.target network.target

[Service]
Type=forking
User=root
WorkingDirectory=/usr/local/sersync
ExecStart=/usr/local/sersync/bin/inotify.sh -f /usr/local/sersync/etc/sersync.conf -r
TimeoutStopSec=5
Restart=on-failure
LimitNOFILE=204800
[Install]
WantedBy=multi-user.target
EOF
```



## 配置说明

### rsync服务端

```shell
# 配置示例，两个模块分别是backup1和backup2，hosts allow字段根据实际修改
cat /etc/rsyncd.conf
uid = root
gid = root
max connections = 200
port = 873
secrets file = /etc/rsync.pass
ignore errors = yes
reverse lookup = no
log file = /var/log/rsyncd.log

[backup1]
path = /data/file
comment = file
read only = no
list = no
auth users = rsync
hosts allow = 10.255.50.63,10.255.50.64,10.255.60.2

[backup2]
path = /data/db
comment = file
read only = no
list = no
auth users = rsync
hosts allow = 10.255.50.63,10.255.50.64,10.255.60.2

###创建密码验证
echo 'rsync:Ki13W@yYZvbJ' >/etc/rsync.pass
echo 'Ki13W@yYZvbJ' >/etc/rsync.pas

###设置权限
chmod  600 /etc/rsyncd.conf
chmod  600 /etc/rsync.pass
chmod  600 /etc/rsync.pas

###创建目录
mkdir -p /data/file /data/code

###启动
systemctl start rsyncd
systemctl enable rsyncd
```

### 监听配置

>修改配置文件etc/sersync.conf

```shell
#工作目录
work_dir=/usr/local/sersync
logs_dir=${work_dir}/logs
#监听目录
listen_dir=('/data/file' '/data/db')
#rsyncd模块与监听目录备份关系，格式[模式名=监听目录]，要求模式名称唯一
rsyncd_mod=('backup1=/data/file' 'backup2=/data/db')
#模块所在主机地址可以多个地址逗号分隔
rsyncd_ip=('backup1=127.0.0.1' 'backup2=127.0.0.1,192.168.0.163')
#监听忽略匹配
exclude_file_rule=('/data/file=logs|tmp' '/data/db=.gif')
#同步的用户
rsync_user=rsync
#rsync密码文件
rsync_passwd_file=/etc/rsync.pas
#同步超时时间
rsync_timeout=180
#传输限速
rsync_bwlimit=100M
```

## 数据同步验证

```shell
#启动增量同步创建文件进行验证
systemctl daemon-reload
systemctl start sersync
```

## 其他说明

> 对于目录深度深、文件数量众多的场景，inotify监听启动时间较长；

## 变更记录

> 2022-08-12
>
> * 解决带空格文件同步错误的问题
> * 解决flock锁文件名过长的问题
> * 增加必要日志
>
> 2023-03-23
>
> * 解决带特殊字符文件同步错误的问题
> * 分离配置文件
> * 脚本优化
