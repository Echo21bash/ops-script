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
Type=simple
User=root
WorkingDirectory=/usr/local/sersync
ExecStart=/usr/local/sersync/bin/inotify.sh -f /usr/local/sersync/etc/sersync.conf
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
secrets file = /etc/rsync.secret
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
echo 'rsync:Ki13W@yYZvbJ' >/etc/rsync.secret
echo 'Ki13W@yYZvbJ' >/etc/rsync.passwd

###设置权限
chmod  600 /etc/rsyncd.conf
chmod  600 /etc/rsync.secret
chmod  600 /etc/rsync.passwd

###创建目录
mkdir -p /data/file /data/db

###启动
systemctl start rsyncd
systemctl enable rsyncd
```

### 监听配置

>修改配置文件etc/sersync.conf

```shell
##############################通用配置##############################
#工作目录
work_dir=/usr/local/sersync
#日志目录
logs_dir=${work_dir}/logs
##############################通用配置##############################

##############################监听配置##############################
#监听目录支持多个
listen_dir=('/data/file' '/data/db' '/data/img')
#监听忽略匹配
#exclude_file_rule=('/data/file=logs|tmp' '/data/img=.gif')
##############################监听配置##############################

##############################同步配置##############################
#首次全量同步
full_rsync_first_enable=1
#实时同步配置
real_time_sync_enable=1
#周期性全量同步
full_rsync_enable=1
#全量同步周期单位d
full_rsync_interval=15
#rsyncd模块与监听目录备份关系，格式[模式名=监听目录,监听目录]一个模式可以对应
#多个待同步目录逗号分隔，要求模式名称唯一，一个带同步目录只能对应一个模块，否则
#第一个生效，同步内容在形如_data_file、_data_db、_data_img目录下。
rsyncd_mod=('backup1=/data/file,/data/db' 'backup2=/data/img')
#模块所在主机地址支持多个地址使用逗号分隔，多个地址实现多份备份
rsyncd_ip=('backup1=127.0.0.1' 'backup2=127.0.0.1,192.168.0.163')
#同步的用户
rsync_user=rsync
#rsync密码文件
rsync_passwd_file=/etc/rsync.passwd
#同步超时时间
rsync_timeout=180
#传输限速
rsync_bwlimit=50M
##############################同步配置##############################
```

## 数据同步验证

```shell
#启动增量同步创建文件进行验证
systemctl daemon-reload
systemctl start sersync
```

## Docker容器

```shell
#修改配置文件并且将需要同步的目录挂载到容器
#支持的环境变量及其说明
#运行模式sersync为监听同步将文件同步到远程服务器，rsyncd为rsync模式daemon。
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

docker run --name sersync --privileged -itd -v /data/file:/data/file \
-v /data/db:/data/db \
-v /etc/rsync.passwd:/etc/rsync.passwd \
-v /usr/local/sersync/etc/sersync.conf:/usr/local/sersync/etc/sersync.conf \
echo21bash/sersync:1.0
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
