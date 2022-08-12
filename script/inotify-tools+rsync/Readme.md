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
ExecStart=/usr/local/sersync/inotify.sh
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
# 配置示例，两个模块分别是file和code
cat /etc/rsyncd.conf
uid = root
gid = root
max connections = 200
port = 873
secrets file = /etc/rsync.pass
ignore errors = yes
reverse lookup = no

[file]
path = /data/file
comment = file
read only = no
list = no
auth users = rsync
hosts allow = 10.255.50.63,10.255.50.64,10.255.60.2

[code]
path = /data/code
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

```shell
#inotify.sh配置说明
# 定义一个关联数组，下标中括号为rsync模块名称，值为需要监听的目录
declare -A rsync_module_name=([file]='/file' [code]='/code')
# 定义一个关联数组，下标中括号为rsync模块名称，值为需要排除的文件或目录可以，没有可以不配置
declare -A exclude_file_rule=([file]='tmp|.log')
# rsync脚本路径
sersync_dir=/usr/local/sersync/sersync.sh
# 文件锁临时目录
lockfile_dir=/tmp/inotify-lock

#sersync.sh配置说明
# 配置密码验证文件
rsync_passwd_file=/etc/rsync.pas
# 目标ip
des_ip=(192.168.74.20)
# 验证用户名
user=rsync
```

## 数据同步验证

```shell
#启动增量同步创建文件进行验证
systemctl daemon-reload
systemctl start sersync
```

## 其他说明

> 对于目录深度深、文件数量众多的场景，inotify监听启动时间较长；
