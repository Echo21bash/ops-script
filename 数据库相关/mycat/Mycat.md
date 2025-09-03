# Mycat知识库

## 安装

### 系统要求

- Linux/Unix 系统（推荐 CentOS 7+ 或 Ubuntu 18.04+）
- Java 环境：JDK 1.7+（推荐 OpenJDK 8）
- MySQL 服务（用于后端数据库）

### 依赖安装

```shell
# 安装 JDK (以 Ubuntu 为例)
sudo apt update
sudo apt install openjdk-8-jdk

# 验证 Java 安装
java -version

# 安装 wget 和 unzip
sudo apt install wget unzip
```

### 安装步骤

```shell
wget https://raw.githubusercontent.com/MyCATApache/Mycat-download/master/1.6.7.6/Mycat-server-1.6.7.6-release-20200226090641-linux.tar.gz
tar -zxvf Mycat-server-1.6.7.6-release-20200226090641-linux.tar.gz
mv mycat /usr/local/

# 编辑环境变量文件
vim /etc/profile.d/mycat.sh

# 添加以下内容
export MYCAT_HOME=/usr/local/mycat
export PATH=$PATH:$MYCAT_HOME/bin

# 使配置生效
source /etc/profile

chown -R $(whoami) /usr/local/mycat
chmod -R 755 /usr/local/mycat

# 启动服务
cd /usr/local/mycat/bin
./mycat start

# 查看启动状态
./mycat status

# 查看日志（启动过程约10-30秒）
tail -f ../logs/wrapper.log
```

## 配置说明

### 核心配置文件位置

```shell
/usr/local/mycat/conf/
├── server.xml       # 用户权限配置
├── schema.xml       # 逻辑库表配置
├── rule.xml         # 分片规则配置
├── log4j2.xml       # 日志配置
└── wrapper.conf     # jvm等参数配置
```

### server.xml（用户配置）

```xml
<user name="root" defaultAccount="true">
    <property name="password">123456</property>
    <property name="schemas">TESTDB</property>
</user>

<user name="user">
    <property name="password">user</property>
    <property name="schemas">TESTDB</property>
    <property name="readOnly">true</property>
</user>
```

### schema.xml（逻辑库表配置）

>balance:负载均衡类型：
>
>0：不开启读写分离机制，所有读操作都发送到当前可用的writeHost上
>
>1：全部的readHost与stand by writeHost参与select语句的负载均衡，
>
>2：所有读操作都随机在writeHost、readHost上分发
>
>3：所有读请求随机分发到writeHost对应的readHost执行，writeHost不负担读压力
>
>writeType:负载均衡类型：
>
>0：所有写操作发送到配置的第一个writeHost，当第一个writeHost宕机时，切换到第二个writeHost，重新启动后以切换后的为准，切换记录在配置文件：dnindex.properties中
>
>1：所有写操作都随发送到配置的writeHost
>
>switchType:切换方式：
>
>-1：不自动切换
>
>1：自动切换（默认）
>
>2：基于MySql主从同步的状态来决定是否切换

```xml
<!-- 定义逻辑库 -->
<schema name="TESTDB" checkSQLschema="false" sqlMaxLimit="100">
    <!-- 定义逻辑表 -->
    <table name="employee" dataNode="dn1,dn2" rule="sharding-by-intfile"/>
</schema>

<!-- 定义数据节点 -->
<dataNode name="dn1" dataHost="localhost1" database="db1" />
<dataNode name="dn2" dataHost="localhost1" database="db2" />

<!-- 定义物理数据库 -->
<dataHost name="localhost1" maxCon="1000" minCon="10" balance="0"
          writeType="0" dbType="mysql" dbDriver="native">
    <heartbeat>select user()</heartbeat>
    <writeHost host="hostM1" url="192.168.0.1:3306" 
               user="dbuser" password="dbpass"/>
</dataHost>
```

### rule.xml（分片规则）

```xml
<tableRule name="sharding-by-intfile">
    <rule>
        <columns>shard_id</columns>
        <algorithm>hash-int</algorithm>
    </rule>
</tableRule>

<function name="hash-int" class="io.mycat.route.function.PartitionByFileMap">
    <property name="mapFile">partition-hash-int.txt</property>
</function>
```

## 基本操作命令

### 服务管理

```shell
# 启动
./mycat start

# 停止
./mycat stop

# 重启
./mycat restart

# 查看状态
./mycat status
```

### 连接管理

```shell
# 数据端口（默认8066）
mysql -uroot -p123456 -h127.0.0.1 -P8066

# 管理端口（默认9066）
mysql -uroot -p123456 -h127.0.0.1 -P9066

# 管理命令
show @@help;          # 查看帮助
show @@version;       # 查看版本
show @@connection;    # 查看连接
show @@connection.sql;# 查看连接正在执行的sql
show @@backend;       # 查看后端状态
show @@threadpool;    # 当前线程池的执行情况，是否有积压(active_count)以及task_queue_size
show @@backend;       # 显示后端物理库连接信息，包括当前连接数，端口等信息
show @@heartbeat;     # 当前后端物理库的心跳检测情况,RS_CODE为1表示心跳正常
show @@session;       # 发送给的sql
show @@datanode;      # 显示数据节点的访问情况，包括每个数据节点当前活动连接数(active),空闲连接数（idle）以及最大连接数(maxCon) size，EXECUTE参数表示从该节点获取连接的次数，次数越多，说明访问该节点越多
show @@datasource;    # 显示数据节点
show @@sql.slow;      # 显示慢sql
reload @@config;      # 重新加载配置文件schema.xml
reload @@config_all   # 重新加载所有配置文件
```

