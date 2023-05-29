# 数据同步方案

## 同步原理

> Inotify，它是在内核 2.6.13 版本中引入的一个新功能，它为用户态监视文件系统的变化提供了强大的支持，允许监控程序打开一个独立文件描述符，并针对事件集监控一个或者多个文件，例如打开、关闭、移动/重命名、删除、创建或者改变属性。

**基于inotify监听文件事件类型，然后调用rsync进行远程同步到rsyncd服务端**

## 脚本特点

>* 支持实时同步；
>* 支持周期性全量同步；
>* 支持启动时首次同步；
>* 支持历史备份数据保留指定天数；
>* 删除多余事件减少资源使用；

## 组件说明

> * inotify、rsync需要部署在需要同步的服务器；
> * rsyncd需要部署在备份服务器用于接收客户端数据；
> * inotify.sh脚本用于监听目录变化并处理重复事件；
> * rsync.sh脚本用于对错误码24屏蔽；
> * sersync.sh脚本用于根据传入的参数调用rsync与远程服务器(依赖rsyncd服务)进行数据增量同步；

## 备份服务安装

### 虚拟机部署

#### 安装rsync

```shell
###安装rsync
yum install rsync -y

###创建密码验证
echo 'rsync:Ki13W@yYZvbJ' >/etc/rsyncd.secret
echo 'Ki13W@yYZvbJ' >/etc/rsync.passwd

###设置权限
chmod  600 /etc/rsyncd.conf
chmod  600 /etc/rsyncd.secret
chmod  600 /etc/rsync.passwd
```

#### 创建配置文件

```shell
# 配置示例，两个模块分别是backup1和backup2，hosts allow字段根据实际修改
cat > /etc/rsyncd.conf <<'EOF'
uid = root
gid = root
max connections = 200
port = 873
secrets file = /etc/rsyncd.secret
ignore errors = yes
reverse lookup = no
log file = /var/log/rsyncd.log

[backup1]
path = /data/backup1
comment = backup1
read only = no
list = no
auth users = rsync
hosts allow = 10.255.50.63,10.255.50.64,10.255.60.2

[backup2]
path = /data/backup2
comment = backup2
read only = no
list = no
auth users = rsync
hosts allow = 10.255.50.63,10.255.50.64,10.255.60.2
EOF

###创建目录
mkdir -p /data/backup1 /data/backup2
```

#### 创建日志分割

```shell
cat > /etc/logrotate.d/rsync <<'EOF'
/var/log/rsyncd.log{
notifempty
daily
rotate 7
}
EOF
```

#### 启动rsyncd

```shell
###启动
systemctl start rsyncd
systemctl enable rsyncd
```

### 容器部署

#### 启动容器

```shell
docker run --name rsyncd --privileged -itd -p 873:873 \
-e RUN_MODE=rsyncd \
-e RSYNCD_USER=rsync \
-e RSYNCD_PASSWD="Ki13W@yYZvbJ" \
-e RSYNCD_MOD_NAME="filebackup" \
-e RSYNCD_PATH=/data \
-v /data:/data \
echo21bash/sersync:1.0
```



## 备份源安装

### 虚拟机部署

#### 安装inotify-tools

> yum安装

```shell
##Centos7
yum install epel-release -y
yum install inotify-tools -y
##Openeuler
yum install inotify-tools -y
```

>编译安装

```shell
cd /usr/local/src/
wget https://ghproxy.com/https://github.com/inotify-tools/inotify-tools/archive/refs/tags/3.22.6.0.tar.gz
tar zxf 3.22.6.0.tar.gz
cd inotify-tools-3.22.6.0/
yum install automake autoconf libtool -y
sh autogen.sh
./configure && make && make install
```

#### 安装rsync

```shell
yum install rsync -y
#认证文件
echo 'Ki13W@yYZvbJ' >/etc/rsync.passwd
chmod  600 /etc/rsync.passwd
```

#### 内核参数优化

```shell
echo 'fs.inotify.max_user_watches = 999999' >> /etc/sysctl.conf
echo 'fs.inotify.max_user_instances = 1024' >> /etc/sysctl.conf
echo 'fs.inotify.max_queued_events = 999999' >> /etc/sysctl.conf
sysctl -p
```

#### 脚本配置

> 下载脚本

```shell
mkdir -p /usr/local/sersync/{bin,etc,logs}
curl -o /usr/local/sersync/bin/inotify.sh https://raw.githubusercontent.com/Echo21bash/ops_script/master/script/inotify-tools%2Brsync/sersync/bin/inotify.sh
curl -o /usr/local/sersync/bin/sersync.sh https://raw.githubusercontent.com/Echo21bash/ops_script/master/script/inotify-tools%2Brsync/sersync/bin/sersync.sh
curl -o /usr/local/sersync/bin/rsync.sh https://raw.githubusercontent.com/Echo21bash/ops_script/master/script/inotify-tools%2Brsync/sersync/bin/rsync.sh
curl -o /usr/local/sersync/bin/stop.sh https://raw.githubusercontent.com/Echo21bash/ops_script/master/script/inotify-tools%2Brsync/sersync/bin/stop.sh
chmod -R +x /usr/local/sersync/bin
```

> 创建配置文件

```shell
###配置守护进程
cat > /usr/local/sersync/etc/sersync.conf <<'EOF'
#########################################通用配置#########################################
#工作目录一般不修改
work_dir=/usr/local/sersync

#日志目录一般不修改
logs_dir=${work_dir}/logs
#########################################通用配置#########################################

#########################################监听配置#########################################
#配置同步目录及其别名，别名用于rsyncd模块下创建目录名，格式[别名=监听目录]，支持多个目录。
listen_dir=('file-backup=/data/file' 'db-backup=/data/db' 'img-backup=/data/img')

#监听忽略匹配，仅实时同步生效，用于忽略临时文同步时配置。
#exclude_file_rule=('/data/file=logs|tmp' '/data/img=.gif')
#########################################监听配置#########################################

#########################################同步配置#########################################
#开启启动时首次全量同步，对于非生产业务直接开启，生产业务根据情况开启。
full_rsync_first_enable=1

#开启文件实时同步，对于小文件如图片、文档等建议开启，对于大文件如镜像建议关闭。同时考虑实时同步对
#业务性能的影响酌情开启，
real_time_sync_enable=1

#实时同步延时(单位s)，实时同步开启后生效，作为实时同步周期。
real_time_sync_delay=60

#开启周期性全量同步，定期对整个目录进行同步。完成首次全量同步后，周期性全量同步只是同步变化的数据
full_rsync_enable=1

#全量同步周期(单位d)
full_rsync_interval=3

#全量同步超时时间单位h
full_rsync_timeout=12

#rsyncd模块与监听目录备份关系，格式[模式名=监听目录,监听目录]一个模式可以对应多个待同步目录逗号
#分隔，要求模式名称唯一，一个待同步目录只能对应一个模块，否则第一个生效。
rsyncd_mod=('backup1=/data/file,/data/db' 'backup2=/data/img')

#模块所在主机地址支持多个地址使用逗号分隔，多个地址实现多份备份
rsyncd_ip=('backup1=127.0.0.1' 'backup2=127.0.0.1,192.168.0.163')

#rsync同步的用户
rsync_user=rsync

#rsync密码文件
rsync_passwd_file=/etc/rsync.passwd

#同步超时时间
rsync_timeout=180

#传输限速
rsync_bwlimit=50M

#rsync额外参数，建议开启--partial、--append-verify、--ignore-missing-args，当前已开启必要参数
#-rlptDRu --delete
extra_rsync_args="-v --partial --append-verify --ignore-missing-args"

#保留多少天内的历史备份(单位d)，防止误删源文件导致数据丢失，备份目录为rsynd模块下/history-backup/，
#建议大于全量同步周期full_rsync_interval的时间否则在未开启实时同步时，数据有误删除无法恢复的风险。
keep_history_backup_days=7
#########################################同步配置#########################################

#########################################其他配置#########################################
#开启额外脚本执行,全量同步前会执行，可用于备份数据库、生成逻辑备份文件、清除无用文件等操作
exec_command_enable=0

#监听目录对应的脚本名称，在scripts目录创建对应的脚本即可
#exec_command_list=('/data/file=clean_file.sh' '/data/img=clean_img.sh')
#########################################其他配置#########################################
EOF
```

> 配置守护进程

```shell
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

> 启动同步

```shell
#启动同步
systemctl daemon-reload
systemctl start sersync
```

### 容器部署

#### 创建配置

```shell
#认证文件
echo 'Ki13W@yYZvbJ' >/etc/rsync.passwd
chmod  600 /etc/rsync.passwd
```

```shell
#创建配置文件
mkdir -p /usr/local/sersync/{bin,etc,logs}
cat > /usr/local/sersync/etc/sersync.conf <<'EOF'
#########################################通用配置#########################################
#工作目录一般不修改
work_dir=/usr/local/sersync

#日志目录一般不修改
logs_dir=${work_dir}/logs
#########################################通用配置#########################################

#########################################监听配置#########################################
#配置同步目录及其别名，别名用于rsyncd模块下创建目录名，格式[别名=监听目录]，支持多个目录。
listen_dir=('file-backup=/data/file' 'db-backup=/data/db' 'img-backup=/data/img')

#监听忽略匹配，仅实时同步生效，用于忽略临时文同步时配置。
#exclude_file_rule=('/data/file=logs|tmp' '/data/img=.gif')
#########################################监听配置#########################################

#########################################同步配置#########################################
#开启启动时首次全量同步，对于非生产业务直接开启，生产业务根据情况开启。
full_rsync_first_enable=1

#开启文件实时同步，对于小文件如图片、文档等建议开启，对于大文件如镜像建议关闭。同时考虑实时同步对
#业务性能的影响酌情开启，
real_time_sync_enable=1

#实时同步延时(单位s)，实时同步开启后生效，作为实时同步周期。
real_time_sync_delay=60

#开启周期性全量同步，定期对整个目录进行同步。完成首次全量同步后，周期性全量同步只是同步变化的数据
full_rsync_enable=1

#全量同步周期(单位d)
full_rsync_interval=3

#全量同步超时时间单位h
full_rsync_timeout=12

#rsyncd模块与监听目录备份关系，格式[模式名=监听目录,监听目录]一个模式可以对应多个待同步目录逗号
#分隔，要求模式名称唯一，一个待同步目录只能对应一个模块，否则第一个生效。
rsyncd_mod=('backup1=/data/file,/data/db' 'backup2=/data/img')

#模块所在主机地址支持多个地址使用逗号分隔，多个地址实现多份备份
rsyncd_ip=('backup1=127.0.0.1' 'backup2=127.0.0.1,192.168.0.163')

#rsync同步的用户
rsync_user=rsync

#rsync密码文件
rsync_passwd_file=/etc/rsync.passwd

#同步超时时间
rsync_timeout=180

#传输限速
rsync_bwlimit=50M

#rsync额外参数，建议开启--partial、--append-verify、--ignore-missing-args，当前已开启必要参数
#-rlptDRu --delete
extra_rsync_args="-v --partial --append-verify --ignore-missing-args"

#保留多少天内的历史备份(单位d)，防止误删源文件导致数据丢失，备份目录为rsynd模块下/history-backup/，
#建议大于全量同步周期full_rsync_interval的时间否则在未开启实时同步时，数据有误删除无法恢复的风险。
keep_history_backup_days=7
#########################################同步配置#########################################

#########################################其他配置#########################################
#开启额外脚本执行,全量同步前会执行，可用于备份数据库、生成逻辑备份文件、清除无用文件等操作
exec_command_enable=0

#监听目录对应的脚本名称，在scripts目录创建对应的脚本即可
#exec_command_list=('/data/file=clean_file.sh' '/data/img=clean_img.sh')
#########################################其他配置#########################################
EOF
```

#### 启动容器

```shell
docker run --name sersync --privileged -itd -v /data/file:/data/file \
-v /data/db:/data/db \
-v /etc/rsync.passwd:/etc/rsync.passwd \
-v /usr/local/sersync/etc/sersync.conf:/usr/local/sersync/etc/sersync.conf \
echo21bash/sersync:1.0
```

## 容器环境变量

> 默认容器以sersync模式运行，配置文件需要挂载到容器内部。以rsyncd模式运行时可以通过以下环境变量配置也可通过挂载配置文件传入配置。

```shell
#运行模式sersync为监听同步将文件同步到远程服务器，rsyncd为rsync模式daemon。
RUN_MODE=${RUN_MODE:-sersync}
#rsync认证用户
RSYNCD_USER=${RSYNCD_USER:-rsync}
#rsync认证密码
RSYNCD_PASSWD=${RSYNCD_PASSWD:-Ki13W@yYZvbJ}
#rsyncd模块名称
RSYNCD_MOD_NAME=${RSYNCD_MOD_NAME:-data}
#rsyncd存储目录
RSYNCD_PATH=${RSYNCD_PATH:-/data}
#rsyncd最大连接数
RSYNCD_MAX_CONN=${RSYNCD_MAX_CONN:-300}
#rsyncd白名单
RSYNCD_HOSTS_ALLOW=${RSYNCD_HOSTS_ALLOW:-0.0.0.0/0}
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
