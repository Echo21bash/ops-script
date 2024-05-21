# Redis手册

## 基础命令

### Redis集群相关命令

#### Redis集群创建

```shell
#创建集群
redis-cli --cluster create 192.168.1.1:6379 \
	192.168.1.2:6379 \
	192.168.1.3:6379 \
	192.168.1.4:6379 \
	192.168.1.5:6379 \
	192.168.1.6:6379 \
	--cluster-replicas 1
#查看集群节点
redis-cli --cluster info 192.168.1.1:6379
#查看集群节点
redis-cli cluster nodes
redis-cli cluster slots
```

Redis集群创建添加节点

```shell
#新增节点
redis-cli --cluster add-node 192.168.1.7:6379 192.168.1.1:6379
redis-cli --cluster add-node 192.168.1.8:6379 192.168.1.1:6379

#为master节点添加分片
redis-cli --cluster reshard 192.168.1.7:6379
How many slots do you want to move (from 1 to 16384)? 500
#这里填写分配多少个槽给5007
What is the receiving node ID? 63aa476d990dfa9f5f40eeeaa0315e7f9948554d
#这里添加接收节点的ID，我们填写5007服务节点的ID
Please enter all the source node IDs.
Type 'all' to use all the nodes as source nodes for the hash slots.
Type 'done' once you entered all the source nodes IDs.
Source node #1: all

#设置从节点
先登录192.168.1.8服务节点
指定192.168.1.8从节点的主节点ID,这里我们填写192.168.1.7服务节点ID
cluster replicate 63aa476d990dfa9f5f40eeeaa0315e7f9948554d
```

#### Redis集群key操作

```shell
#获取所有key
redis-cli -c --cluster call 192.168.1.1:6379  keys \*
```

## 配置说明

### Redis 持久化

#### RDB持久化

> RDB持久化是指将内存中某一时刻的 **数据快照** **全量** 写入到指定的 `rdb 文件` 的持久化技术。 RDB 持久化默认是开启的。 当 Redis 启动时会 **自动读取** **RDB 快照文件**，将数据从硬盘载入到内存， 以恢复 Redis 关机前的数据库状态。

```shell
# Redis 配置文件示例
 
# 时间间隔，表示900秒内至少有1个键被改变则进行持久化
save 900 1
 
# 时间间隔，表示300秒内至少有10个键被改变则进行持久化
save 300 10
 
# 时间间隔，表示60秒内至少有10000个键被改变则进行持久化
save 60 10000
 
# 指定RDB文件名
dbfilename dump.rdb
 
# 指定RDB文件和AOF文件的目录
dir /path/to/your/redis/directory/
 
# 如果配置了主从复制，RDB文件将不会被用于恢复
# 因为数据会通过主服务器复制到从服务器
# 如果你想使用RDB恢复数据，请确保没有配置主从复制
 
# 使用LZF压缩RDB文件，如果你的服务器有硬件压缩能力，则可以关闭
rdbcompression no
 
# 校验RDB文件
rdbchecksum yes
```

#### AOF持久化

> 在Redis中，AOF（Append Only File）持久化是通过保存服务器收到的每一个写操作命令到文件来持久化数据的。当Redis重启时，可以通过重新执行这些命令来恢复数据

```shell
# 开启AOF持久化
appendonly yes
 
# AOF文件的名称，默认为appendonly.aof
appendfilename "appendonly.aof"
 
# 同步策略：
#   everysec：每秒同步一次，可能丢失1秒内的数据。
#   always：每个写命令都同步，效率较低但数据安全性高。
#   no：由操作系统控制同步，通常是每30秒同步一次。
appendfsync everysec
 
# 是否在载入AOF时，对AOF进行校验，若为yes，可能导致载入过程异常慢
aof-load-truncated yes
```

```shell
# 当前AOF文件大小是上次AOF文件大小的一倍且文件大于64MB时进行重写
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
```

```shell
#下面的情况可能会导致Redis的fsync阻塞2s
如果开启了 appendfsync everysec 的fsync策略，并且no-appendfsync-on-rewrite参数为no，则redis在做AOF重写的时候，也会每秒将命令fsync到磁盘上，而此时Redis的写入量大而磁盘性能较差，fsync的等待就会严重；

单纯的写入量大，大到磁盘无法支撑这个写入。例如appendfsync参数的值是everysec，每秒进行一次fsync，而磁盘的性能很差。
```

### 常见故障

#### 集群主从异常切换

```shell
#日志示例
* Asynchronous AOF fsync is taking too long (disk is busy?). Writing the AOF buffer without waiting for fsync to complete, this may slow down Redis

```

```shell
#优化配置
#该属性用于指定， 当 AOF fsync 策略设置为 always 或 everysec 当主进程创建了子进程 正在执行 bgsave 或 bgrewriteaof 时， 主进程是否不调用 fsync() 来做数据同步。设置为 no，双重否定即肯定，主进程会调用 fsync() 做同步。而 yes 则不会调用 fsync() 做数据同步。
#在生产环境中:
#如果 写操作 有可能出现 高并发 的情况，设为 yes;
#大多数为 读操作 高并发，默认为 no。
no-appendfsync-on-rewrite yes

#如果效果不好修改以下配置
#appendfsync no代表write后不会有fsync调用，由操作系统自动调度刷磁盘，性能是最好的。
appendfsync no

#是在不行就是关闭AOF持久化，或者提高磁盘性能。
```
