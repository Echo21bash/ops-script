## MySQL常见问题

### 通过系统线程查找占用CPU资源最高的SQL

1. 使用top查找CPU高的进程

   ```shell
   使用top -H命令打印出所有线程PID
   ```

2. 登陆数据库查询对应的id

   ```sql
   mysql >SELECT `name`,`type`,thread_os_id,processlist_id  FROM performance_schema.`threads` WHERE  thread_os_id=102626;
   ```

3. 查找对应processlist_id，可以确定出正在运行的SQL

   ```sql
   mysql > show processlist;
   ```

### 通过系统线程查找占用IO资源最高的SQL

1. 使用iotop命令打印出所有产生IO的线程

   ```shell
   iotop -u mysql
   ```

2. 通过performance_schema查找占用IO资源最高的线程

   ```sql
   mysql >SELECT `name`,`type`,thread_os_id,processlist_id  FROM performance_schema.`threads` WHERE  thread_os_id=210142;
   ```

3. 查找对应processlist_id，可以确定出正在运行的SQL 

   ```sql
   mysql > show processlist;

## 安全配置

### 安全登录

* 通过mysql_config_editor命令

```shell
#通过mysql_config_editor配置登录方式
mysql_config_editor set -G itp -udba -h 172.16.2.204 -P 8066 -p
#查看配置内容，密码为隐藏增加安全性
[root ~]# mysql_config_editor print --all
[itp]
user = "dba"
password = *****
host = "172.16.2.204"
port = 8066
#通过--login-path参数快捷登录密码不会留痕
mysql --login-path=itp
```

