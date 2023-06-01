# OCFS集群文件系统

## 基本概念 ##

> OCFS2是基于共享磁盘的集群文件系统，它在一块共享磁盘上创建OCFS2文件系统，让集群中的其它节点可以对磁盘进行读写操作。

## 运行环境

### CentOS7

* yum源

```shell
curl -Ls -o /etc/yum.repos.d/public-yum.oracle.repo https://public-yum.oracle.com/public-yum-ol7.repo
```

* 安装内核kernel-uek及工具

```shell
yum install kernel-uek ocfs2-tools -y
```

* 修改启动项加载ocfs2 模块

```shell
grub2-set-default 0
echo ocfs2 >/etc/modules-load.d/ocfs2-modules.conf
```

* 重启服务器

```shell
reboot
```

### Openeuler2203

* 自行编译内核

```shell
自行编译ocfs2内核模块
```

* 安装必要依赖

```shell
yum install -y lsb
```

* ocfs-tools安装

```shell
#可以使用el9平台
wget https://public-yum.oracle.com/repo/OracleLinux/OL9/baseos/latest/x86_64/getPackage/ocfs2-tools-1.8.6-15.el9.x86_64.rpm
yum install -y ocfs2-tools-1.8.6-15.el9.x86_64.rpm
```

* 修改启动项加载ocfs2 模块

```shell
grub2-set-default 0
echo ocfs2 >/etc/modules-load.d/ocfs2-modules.conf
```

* 重启服务器

```shell
reboot
```



# 新建集群

### 创建OCFS集群

> 在每台主机分别执行

* 创建集群

```shell
o2cb add-cluster ocfs2cluster
```

* 修改主机名

```shell
hostnamectl set-hostname node1
hostnamectl set-hostname node2
```

* 添加节点

```shell
#注意-n 后面的参数必须是主机名
o2cb add-node --ip 10.11.11.11 --port 7777 --number 1 ocfs2cluster node1
o2cb add-node --ip 10.11.11.12 --port 7777 --number 2 ocfs2cluster node2
```

* 配置集群参数

```shell
o2cb.init configure
#Load O2CB driver on boot (y/n) [y]:
#Cluster stack backing O2CB [o2cb]:
#Cluster to start on boot (Enter "none" to clear) [ocfs2]: 此处填写集群名称
#Specify heartbeat dead threshold (>=7) [31]:
#Specify network idle timeout in ms (>=5000) [30000]:
#Specify network keepalive delay in ms (>=1000) [2000]:
#Specify network reconnect delay in ms (>=2000) [2000]:
```

* 启动集群

```shell
systemctl enable o2cb.service
systemctl start o2cb.service
```

* 查看集群状态

```shell
#全部显示ok为正常
systemctl status o2cb.service
```

### 挂载共享磁盘

* 将共享磁盘分别挂载linux主机

```shell
#可使用exsi或者iscsi共享磁盘挂载
```
### 创建OCFS2文件系统

> 只需在一台主机执行格式化，其余分别执行

* 格式化为ocfs2文件系统

```shell
mkfs -t ocfs2 -b 4k -C 256K -N 2 -L ocfs2 /dev/sdb
#-C 集群大小参考值
#File System Size	Suggested Minimum Cluster Size 
#1 GB - 10 GB 		8K 
#10GB - 100 GB		16K 
#100 GB - 1 TB 		32K 
#1 TB - 10 TB 		64K 
#10 TB - 16 TB 		128K 
#-N 是最多允许多少主机同时挂载ocfs文件系统
```

* 挂载ocfs文件系统

```shell
mount -t ocfs2 /dev/sdb /opt
```

* 查看挂载情况

```shell
mounted.ocfs2 -f
o2cb.init status
```

# 集群维护

## 向集群中添加节点

> 在集群中任意一台执行

* 查看当前ocfs2卷内的Max Node Slots

```shell
echo 'stats -h' | debugfs.ocfs2 /dev/sdb
```

* 更改Max Node Slots值为3

```shell
#需要将所有挂载该设备的节点umount
tunefs.ocfs2 -N 3 /dev/sdb
```

> 该步骤需要每个节点执行

* 执行o2cb_ctl工具去在线新增节点3到cluster中

```shell
o2cb_ctl -C -i -n node3 -t node -a number=3 -a ip_address=10.11.11.13 -a ip_port=7777 -a cluster=ocfs2cluster
```

> 在node3执行

* 再次查看虚拟机磁盘文件分配大小

```shell
hostnamectl set-hostname node3
#将/etc/ocfs2/cluster.conf拷贝node3
systemctl enable o2cb.service
systemctl start o2cb.service
```

## ocfs2文件系统扩容

> 不支持缩容，登陆ocfs2其中一台节点在线扩容

* 存储设备扩容

```shell
#首先将共享磁盘扩容后并刷新服务端
```

* 扫描磁盘容量

```shell
#sdb为设备名
echo 1 > /sys/block/sdb/device/rescan
#查看容量变化
lsblk
```

* 卸载磁盘

```shell
#卸载除当前操作机器的其他机器磁盘
unmount /dev/sdb
```

* 扩容ocfs2文件系统

```shell
tunefs.ocfs2 -S /dev/sdb
```

* 重新挂载磁盘

```shell
#其他机器重新挂载即可
mount -t ocfs2 /dev/sdb /opt
```

