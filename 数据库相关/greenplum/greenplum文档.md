# GreenPlum性能调优

## 前言

数据库系统一般分为两种类型，一种是面向前台应用的，应用比较简单，但是重吞吐和高并发的OLTP类型；一种是重计算的，对大数据集进行统计分析的OLAP类型。Greenplum属于后者，下面简单介绍下这两种数据库系统的特点。
		OLTP（On-Line Transaction Processing，联机事务处理）系统也称为生产系统，它是事件驱动的、面向应用的，比如电子商务网站的交易系统就是一个典型的OLTP系统。OLTP的基本特点是：

1. 数据在系统中产生；
2. 基于交易的处理系统（Transaction-Based）；
3. 每次交易牵涉的数据量很小；
4. 对响应时间要求非常高；
5. 用户数量非常庞大，主要是操作人员
6. 数据库的各种操作主要基于索引进行。

​		OLAP（On-Line Analytical Processing，联机分析处理）是基于数据仓库的信息分析处理过程，是数据仓库的用户接口部分。OLAP系统是跨部门的、面向主题的，其基本特点是：
本身不产生数据，其基础数据来源于生产系统中的操作数据（OperationalData）；
基于查询的分析系统；
复杂查询经常使用多表联结、全表扫描等，牵涉的数据量往往十分庞大；
响应时间与具体查询有很大关系；
用户数量相对较小，其用户主要是业务人员与管理人员；
由于业务问题不固定，数据库的各种操作不能完全基于索引进行。

​		Greenplum 6针对OLTP的使用场景完成了多项优化，极大的改进了多并发情况下简单查询、删除和更新操作的性能。这些改进包括：
合并Postgres内核版本至9.4，这些合并在带来一系列新功能的同时，也提升了系统的整体性能。例如，引入fastpath等锁优化，可以减少多并发情况下的锁竞争开销。
提供全局死锁检测，从而支持针对同一张HEAP表的并发更新/删除操作。
优化全局事务，从而减少开始事务和结束事务时的延迟。

## 操作系统

### 内核参数

```shell
kernel.shmmni = 4096
kernel.sem = 500 2048000 200 4096
kernel.sysrq = 1
kernel.core_uses_pid = 1
kernel.msgmni = 2048
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_forward = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.conf.all.arp_filter = 1
net.ipv4.ip_local_port_range = 1025 65535
net.core.netdev_max_backlog = 10000
net.core.rmem_max = 2097152
net.core.wmem_max = 2097152
vm.overcommit_memory = 2
kernel.core_pattern=core.%e.%p.%t.%u.%g
net.ipv4.ip_local_reserved_ports=5432,6543
net.ipv4.ip_forward = 0
net.ipv4.conf.default.accept_source_route = 0
kernel.core_uses_pid = 1
net.ipv4.tcp_syncookies = 1
kernel.msgmax = 65536
kernel.msgmni = 2048
kernel.msgmnb = 65536
net.ipv4.tcp_max_syn_backlog=4096
net.ipv4.ip_local_port_range = 1025 65535
net.core.netdev_max_backlog=10000
vm.overcommit_memory=2
vm.overcommit_ratio=95
net.ipv4.conf.all.arp_filter = 1
vm.swappiness=10
vm.dirty_background_ratio = 3
vm.dirty_ratio = 10
net.ipv4.tcp_max_tw_buckets=100
net.ipv4.tcp_fin_timeout=10
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.all.disable_ipv6 = 1

net.core.rmem_default=33554432
net.core.rmem_max =67108864
vm.min_free_kbytes = 15833622
```

### 系统限制

```shell
echo '*                  -        nofile         1024000'>>/etc/security/limits.conf
echo '*                  -        nproc          65536'>>/etc/security/limits.conf
```



## 数据库



由于ITP业务属于OLTP场景，所以要对GreenPlum数据库进行针对性优化

### 并发配置

* 开启全局死锁检测功能

  ```shell
  #在Greenplum 6中其默认关闭，需要打开它才可以支持并发更新/删除操作；Greenplum 5并不支持
  gpconfig -c gp_enable_global_deadlock_detector -v on
  ```

* 禁用GPORCA优化器

  ```shell
  gpconfig -c optimizer -v off	
  ```

* 主动刷盘的频率

  ```shell
  #checkpoint主动刷盘的频率，默认值8会降低刷盘频率，但是每次刷盘的数据量较大，导致整个集群瞬时的性能下降。针对OLTP大量更新类语句适当调小此设置会增加刷盘频率，但由于每次刷盘数据量变小，平均性能会有较明显提升；
  gpconfig -c checkpoint_segments -v 2 --skipvalidation
  ```

* 内存缓冲区大小

  ```shell
  #官方建议max_connections*16K，不宜过大
  gpconfig -c shared_buffers -v 125MB
  ```

* 最大文件描述符

  ```shell
  #每个服务器进程允许同时打开的最大文件数目默认1000
  gpconfig -c max_files_per_process -v 2000
  ```

* 最大连接数

  ```shell
  #主节点数必须小于数据节点数目
  gpconfig -c max_connections -v 1000 -m 500
  ```

* 最大预备事务数

  ```shell
  #建议和主节点最大连接数一致
  gpconfig -c max_prepared_transactions -v 500
  ```

* 关闭持久化调用

  ```shell
  #不强制刷新数据到磁盘，在断电或者系统出现问题时有数据丢失的风险。
  gpconfig -c fsync -v off --skipvalidation
  ```

* 调整事务提交参数

  ```shell
  #调整事务提交参数，不强制将WAL写入磁盘，只需写到缓存中就会向客户端返回提交成功
  gpconfig -c synchronous_commit -v off
  ```

**注意：**gp_enable_global_deadlock_detector optimizer这两个参数对OLTP场景最为重要，fsync synchronous这两个参数视数据丢失容忍性谨慎设置

### 内存配置

* gp_vmem_protect_limit服务器配置参数指定单个segment的所有活动postgres进程在 任何给定时刻能够消耗的内存量。查询一旦超过该值则会失败。可使用下面的计算方法为gp_vmem_protect_limit 估计一个安全值。

  使用这个公式计算gp_vmem（Greenplum数据库可用的主机内存）：

  ```
  gp_vmem = ((SWAP + RAM) – (7.5GB + 0.05 * RAM)) / 1.7
  ```

  其中SWAP是主机的交换空间（以GB为单位）而RAM是主机上安装的 内存（以GB为单位）。

  通过将总的Greenplum数据库内存除以活动主segment的最大数量来计算

  ```
  gp_vmem_protect_limit = gp_vmem / max_acting_primary_segments
  ```

转换成兆字节就是gp_vmem_protect_limit

设置示例根据情况修改

```shell
gpconfig -c gp_vmem_protect_limit  -v 16384
gpconfig -c max_statement_mem -v 8000MB
gpconfig -c statement_mem -v 1000MB
```

### 其他配置

* 强制走索引

  ```shell
  gpconfig -c enable_seqscan -v off
  gpconfig -c enable_indexscan -v on
  ```

* 每个segment分配的cpu的个数

  ```shell
  #默认值4
  gpconfig -c gp_resqueue_priority_cpucores_per_segment -v 8
  ```

* 日志相关配置

  ```shell
  #有效值是none（off），ddl，mod和all
  gpconfig -c log_statement -v none -m all
  #有效值是-1表示关闭,0表示记录所有,100表示记录大于100ms的sql
  gpconfig -c log_min_duration_statement -v -1 -m 100
  #有效值是debug1、info、notice、warning、log、error、fatal、panic
  gpconfig -c log_min_messages -v fatal -m error
  ```



# GreenPlum监控

## 监控方案

Prometheus+grafana

参考链接https://github.com/tangyibo/greenplum_exporter

# GreenPlum维护

## 基础命令

### 用户与角色

```sql
---查看用户信息
select * from pg_user;
---新增用户
create user tableau with nosuperuser nocreatedb password 'tableau';
---更改密码
alter user gpadmin with password 'gpadmin';

```

### 连接数

```sql
---获取锁信息
select * from gp_toolkit.gp_locks_on_relation;
---获取当前正在运行的SQL
select * from pg_stat_activity;
---获取当前活跃的连接数
select count(*) from pg_stat_activity where state = 'active';

---长事务查询
SELECT
  pid,
  client_addr,
  usename,
  datname,
  waiting,
  clock_timestamp() - xact_start AS xact_age,
  clock_timestamp() - query_start AS query_age,
  state,
  query
FROM
  pg_stat_activity
WHERE
  (
    now() - xact_start > interval '10 sec'
    OR now() - query_start > interval '10 sec'
  )
  AND query !~ '^COPY'
  AND state LIKE '%transaction%'
ORDER BY
  coalesce(xact_start, query_start);
  
---长连接查询
SELECT
  pid,
  client_addr,
  usename,
  datname,
  waiting,
  clock_timestamp() - xact_start AS xact_age,
  clock_timestamp() - query_start AS query_age,
  state,
  query
FROM
  pg_stat_activity
WHERE
  (
    now() - xact_start > interval '1 day'
    OR now() - query_start > interval '1 day'
  )
  AND query !~ '^COPY'
  AND NOT STATE LIKE '%transaction%'
ORDER BY
  coalesce(xact_start, query_start);
```

### 数据表维护

```sql
---查看表的存储结构
select distinct relstorage from pg_class;
--- a  -- 行存储AO表    
--- h  -- heap堆表、索引    
--- x  -- 外部表(external table)    
--- v  -- 视图    
--- c  -- 列存储AO表

---查询当前数据库有哪些AO表
select t2.nspname, t1.relname from pg_class t1, pg_namespace t2 where t1.relnamespace=t2.oid and relstorage in ('c', 'a');

---查询当前数据库有哪些HEAP表
select t2.nspname, t1.relname from pg_class t1, pg_namespace t2 where t1.relnamespace=t2.oid and relstorage in ('h');

---查询表大小
select pg_size_pretty(pg_relation_size('schemaname.tablename'));

---查询当前库所有表大小
SELECT
	table_schema || '.' || TABLE_NAME AS table_full_name,
	pg_size_pretty ( pg_total_relation_size ( '"' || table_schema || '"."' || TABLE_NAME || '"' ) ) AS SIZE 
FROM
	information_schema.tables 
ORDER BY
	pg_total_relation_size ( '"' || table_schema || '"."' || TABLE_NAME || '"' ) DESC;
	
---查询当前库所有表大小	
SELECT
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
    pg_size_pretty(pg_indexes_size(c.oid)) AS index_size,
    pg_size_pretty(pg_total_relation_size(c.oid) - pg_indexes_size(c.oid)) AS data_size,
    nspname AS schema_name,
    relname AS table_name
FROM
    pg_class c
LEFT JOIN
    pg_namespace n ON n.oid = c.relnamespace
WHERE
    relkind = 'r'
    AND nspname NOT LIKE 'pg_%'
    AND nspname != 'information_schema'
ORDER BY
    pg_total_relation_size(c.oid) DESC;
    
--单个库大小
select pg_size_pretty(pg_database_size('dbname'));
--所有库大小
select datname,pg_size_pretty(pg_database_size(datname)) from pg_database;

---查看表状态
select * from pg_stat_all_tables;
```

### 节点维护

```sql
select * from gp_segment_configuration;
```

### 集群维护

#### gpstate命令

```shell
gpstate
命令     参数   作用 
gpstate -b => 显示简要状态
gpstate -c => 显示主镜像映射
gpstart -d => 指定数据目录（默认值：$MASTER_DATA_DIRECTORY）
gpstate -e => 显示具有镜像状态问题的片段
gpstate -f => 显示备用主机详细信息
gpstate -i => 显示GRIPLUM数据库版本
gpstate -m => 显示镜像实例同步状态
gpstate -p => 显示使用端口
gpstate -Q => 快速检查主机状态
gpstate -s => 显示集群详细信息
gpstate -v => 显示详细信息

```

#### gpconfig命令

```shell
命令    参数                              作用
gpconfig -c => --change param_name  通过在postgresql.conf 文件的底部添加新的设置来改变配置参数的设置。
gpconfig -v => --value value 用于由-c选项指定的配置参数的值。默认情况下，此值将应用于所有Segment及其镜像、Master和后备Master。
gpconfig -m => --mastervalue master_value 用于由-c 选项指定的配置参数的Master值。如果指定，则该值仅适用于Master和后备Master。该选项只能与-v一起使用。
gpconfig -masteronly =>当被指定时，gpconfig 将仅编辑Master的postgresql.conf文件。
gpconfig -r => --remove param_name 通过注释掉postgresql.conf文件中的项删除配置参数。
gpconfig -l => --list 列出所有被gpconfig工具支持的配置参数。
gpconfig -s => --show param_name 显示在Greenplum数据库系统中所有实例（Master和Segment）上使用的配置参数的值。如果实例中参数值存在差异，则工具将显示错误消息。使用-s=>选项运行gpconfig将直接从数据库中读取参数值，而不是从postgresql.conf文件中读取。如果用户使用gpconfig 在所有Segment中设置配置参数，然后运行gpconfig -s来验证更改，用户仍可能会看到以前的（旧）值。用户必须重新加载配置文件（gpstop -u）或重新启动系统（gpstop -r）以使更改生效。
gpconfig --file => 对于配置参数，显示在Greenplum数据库系统中的所有Segment（Master和Segment）上的postgresql.conf文件中的值。如果实例中的参数值存在差异，则工具会显示一个消息。必须与-s选项一起指定。
gpconfig --file-compare 对于配置参数，将当前Greenplum数据库值与主机（Master和Segment）上postgresql.conf文件中的值进行比较。
gpconfig --skipvalidation 覆盖gpconfig的系统验证检查，并允许用户对任何服务器配置参数进行操作，包括隐藏参数和gpconfig无法更改的受限参数。当与-l选项（列表）一起使用时，它显示受限参数的列表。 警告： 使用此选项设置配置参数时要格外小心。
gpconfig --verbose 在gpconfig命令执行期间显示额外的日志信息。
gpconfig --debug 设置日志输出级别为调试级别。
gpconfig -? | -h | --help 显示在线帮助。
```

#### gpstart命令

```shell
命令     参数   作用 
gpstart -a => 快速启动
gpstart -d => 指定数据目录（默认值：$MASTER_DATA_DIRECTORY）
gpstart -q => 在安静模式下运行。命令输出不显示在屏幕，但仍然写入日志文件。
gpstart -m => 以维护模式连接到Master进行目录维护。例如：$ PGOPTIONS='-c gp_session_role=utility' psql postgres
gpstart -R => 管理员连接
gpstart -v => 显示详细启动信息
```

#### gpstop命令

```shell
命令     参数   作用 
gpstop -a => 快速停止
gpstop -d => 指定数据目录（默认值：$MASTER_DATA_DIRECTORY）
gpstop -m => 维护模式
gpstop -q => 在安静模式下运行。命令输出不显示在屏幕，但仍然写入日志文件。
gpstop -r => 停止所有实例，然后重启系统
gpstop -u => 重新加载配置文件 postgresql.conf 和 pg_hba.conf
gpstop -v => 显示详细启动信息
gpstop -M fast          => 快速关闭。正在进行的任何事务都被中断。然后滚回去。
gpstop -M immediate     => 立即关闭。正在进行的任何事务都被中止。不推荐这种关闭模式，并且在某些情况下可能导致数据库损坏需要手动恢复。
gpstop -M smart         => 智能关闭。如果存在活动连接，则此命令在警告时失败。这是默认的关机模式。
gpstop --host hostname  => 停用segments数据节点，不能与-m、-r、-u、-y同时使用 
```

#### gprecoverseg命令

```shell
命令     参数   作用 
gprecoverseg -a => 快速恢复
gprecoverseg -F => 全量恢复
gprecoverseg -i => 指定恢复文件
gprecoverseg -d => 指定数据目录
gprecoverseg -l => 指定日志文件
gprecoverseg -r => 平衡数据
gprecoverseg -s => 指定配置空间文件
gprecoverseg -o => 指定恢复配置文件
gprecoverseg -p => 指定额外的备用机
gprecoverseg -S => 指定输出配置空间文件
```



## 数据表维护

### 数据表统计信息优化

* ANALYZE命令

  ANALYZE

  限制
  	ANALYZE 会给目标表加 SHARE UPDATE EXCLUSIVE 锁，也就是与 UPDATE，DELETE，还有 DDL 语句冲突。
  时机
  	根据上文所述，ANALYZE 会加锁并且也会消耗系统资源，因此运行命令需要选择合适的时机尽可能少的运行。根据 Greenplum 官网建议，以下3种情况发生后建议运行 ANALYZE
  	批量加载数据后，比如 COPY
  	创建索引之后
  	INSERT, UPDATE, and DELETE 大量数据之后
  自动化
  	除了手动运行，ANALYZE 也可以自动化。实际上默认情况下，我们对空表写入数据后， Greenplum 也会自动帮我们收集统计信息，不过之后在写入数据，就需要手动操作了。
  	有2个参数可以用来调整自动化收集的时机，gp_autostats_mode 和 gp_autostats_on_change_threshold。gp_autostats_mode 默认是 on_no_stats，也就是如果表还没有统计信息，这时候写入数据会导致自动收集，这之后，无论表数据变化多大，都只能手动收集了。如果将 gp_autostats_mode 修改为 on_change ，就是在数据变化量达到 gp_autostats_on_change_threshold 参数配置的量之后，系统就会自动收集统计信息。

### 数据表膨胀优化

* VACUUM命令

  VACUUM
  	Greenplum是基于MVCC版本控制的，所有的delete并没有删除数据，而是将这一行数据标记为删除，
  	而且update其实就是delete加insert。所以，随着操作越来越多，表的大小也会越来越大。对于OLAP
  	应用来说，大部分表都是一次导入后不再修改，所以不会出现这个问题。
  	但是对于数据字典来说，就会随着时间表越来越大，其中的数据垃圾越来越多。
  语法：

  vacuum table;

  vacuum full table;

  1）简单的vacuum table只是简单的回收空间且令其可以再次使用。可以缓解表的增长。

  这个命令执行的时候，其他操作仍可以对标的读写并发操作，没有请求排他锁。

  2）vacuum full执行更广泛的处理，包括跨块移动行，把表压缩到最少的磁盘块数目存储。

  这个命令执行的时候，需要加排他锁。

  3）PostgreSQL中，此功能是自动执行。但是Greenplum中大部分的表是不需要vacuum的，

  所以vacuum的autovacuum是关闭的。并且无法修改，需要手动通过脚本定时执行

  4）执行vacuum后，最好对表上的索引进行重建

**注意：** *在执行vacuum时如有未释放的事务时垃圾回收会失败，需要将所有事务中断执行，最好在夜晚执行*

```sql
---查看表膨胀率 脏数据大于1万条按照膨胀率降序打印20条
SELECT
  schemaname || '.' || relname as table_name,
  pg_size_pretty(
    pg_relation_size('"' || schemaname || '"' || '.' || relname)
  ) as table_size,
  n_dead_tup,
  n_live_tup,
  round(n_dead_tup * 100 / (n_live_tup + n_dead_tup), 2) AS dead_tup_ratio
FROM
  pg_stat_all_tables
WHERE
  n_dead_tup >= 10000
ORDER BY
  dead_tup_ratio DESC
LIMIT
  20;
```

### 数据表年龄

> 数据库用txid来记录事务,目前使用GP版本txid类型是int2，所以txid最大值是2^31=2147483648，每个表里都有xmin和xmax来记录当前的事务,事务号到2147483648就会用尽，有两个参数xid_stop_limit,xid_warn_limit控制告警和停止服务。

```sql
---查询现在的各个数据库的年龄
SELECT datname, datfrozenxid ,age(datfrozenxid) FROM pg_database ORDER BY 3 DESC ;
---检查segment数据库年龄
SELECT gp_segment_id,datname, age(datfrozenxid) FROM gp_dist_random('pg_database') ORDER BY 3 DESC;
---表级年龄查询
SELECT 
    n.nspname AS schema_name,
    c.relname AS table_name,
    MAX(age(c.relfrozenxid)) AS max_xid_age,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS table_size,
    CASE 
        WHEN MAX(age(c.relfrozenxid)) > 1000000000 THEN '紧急冻结'
        WHEN MAX(age(c.relfrozenxid)) > 500000000 THEN '优先冻结'
        WHEN MAX(age(c.relfrozenxid)) > 100000000 THEN '计划冻结'
        ELSE '正常'
    END AS action
FROM 
    gp_dist_random('pg_class') AS c
JOIN 
    pg_namespace n ON n.oid = c.relnamespace
WHERE 
    c.relkind = 'r'
    ---默认处理堆表
	AND c.relstorage in ('h')
GROUP BY 
    n.nspname, c.relname, c.oid
ORDER BY 
    MAX(age(c.relfrozenxid)) DESC
    
---生成命令
SELECT 'VACUUM FREEZE VERBOSE ' || quote_ident(nspname) || '.' || quote_ident(relname) || ';'
FROM (
    SELECT n.nspname, c.relname
    FROM gp_dist_random('pg_class') AS c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r' AND c.relstorage in ('h') AND age(c.relfrozenxid) > 1000000000
) AS critical_tables;
```

> 临时库处理，临时库不允许登录

```sql
SELECT datallowconn from pg_database where datname='template0';

set allow_system_table_mods='DML';
update pg_database set datallowconn='t' where datname='template0';
\c template0
vacuum freeze;
\c postgres gpadmin
set allow_system_table_mods='DML';
update pg_database set datallowconn='f' where datname='template0';
```



## 集群维护

### 主节点故障

当master节点故障后，我们需要激活standby节点作为新的master节点（如果服务器允许，把vip也切换到standby服务器）
在激活standby节点的可以直接指定新的standby节点，也可以等原master服务器恢复后，指定原master节点为standby节点
这里我就不关服务器了，直接模拟master节点故障的状态

1. 关闭master节点

   ```shell
   [gpadmin@l-test5 ~]$ gpstop -a -m 
   [gpadmin@l-test5 ~]$ psql
   	psql: could not connect to server: No such file or directory
   		Is the server running locally and accepting
   		connections on Unix domain socket "/tmp/.s.PGSQL.65432"?
   ```

   

2. 激活standby节点

   ```shell
   [gpadmin@l-test6 ~]$ gpactivatestandby -a -d /export/gp_data/master/gpseg-1/
   20180211:15:19:48:016771 gpactivatestandby:l-test6:gpadmin-[INFO]:------------------------------------------------------
   20180211:15:19:48:016771 gpactivatestandby:l-test6:gpadmin-[INFO]:-Standby data directory    = /export/gp_data/master/gpseg-1
   20180211:15:19:48:016771 gpactivatestandby:l-test6:gpadmin-[INFO]:-Standby port             = 65432
   20180211:15:19:48:016771 gpactivatestandby:l-test6:gpadmin-[INFO]:-Standby running           = yes
   20180211:15:19:48:016771 gpactivatestandby:l-test6:gpadmin-[INFO]:-Force standby activation  = no
   .
   .
   .
   ```

 3. 切换服务器vip

      ```shell
      ##原master节点服务器卸载vip:
      [root@l-test5 ~]# 
      [root@l-test5 ~]# ip a d 10.0.0.1/32 brd + dev bond0
      ##原standby节点服务器挂载vip:
      [root@l-test6 ~]# 
      [root@l-test6 ~]# ip a a  10.0.0.1/32 brd + dev bond0 && arping -q -c 3 -U -I bond0 10.0.0.1
      ```

   4. 指定新的standby节点

      ```shell
      ##我们指定原master节点为新的standby节点服务器
      ##需要先删除原master的数据文件，然后重新执行初始化standby节点即可
      
      [gpadmin@l-test6 ~]$ gpinitstandby -a -s l-test5
      20180211:15:28:56:019106 gpinitstandby:l-test6:gpadmin-[INFO]:-Validating environment and parameters for standby initialization...
      20180211:15:28:56:019106 gpinitstandby:l-test6:gpadmin-[INFO]:-Checking for filespace directory /export/gp_data/master/gpseg-1 on l-test5
      20180211:15:28:56:019106 gpinitstandby:l-test6:gpadmin-[ERROR]:-Filespace directory already exists on host l-test5
      20180211:15:28:56:019106 gpinitstandby:l-test6:gpadmin-[ERROR]:-Failed to create standby
      20180211:15:28:56:019106 gpinitstandby:l-test6:gpadmin-[ERROR]:-Error initializing standby master: master data directory exists
      ----------注意，这步是在原master节点操作-------
      [gpadmin@l-test5 ~]$ cd /export/gp_data/master/
      [gpadmin@l-test5 /export/gp_data/master]$ ll
      total 4
      drwx------ 17 gpadmin gpadmin 4096 Feb 11 15:17 gpseg-1
      [gpadmin@l-test5 /export/gp_data/master]$ rm -rf gpseg-1/
      [gpadmin@l-test5 /export/gp_data/master]$ ll
      total 0
      [gpadmin@l-test5 /export/gp_data/master]$ 
      ----------
      
      [gpadmin@l-test6 ~]$ gpinitstandby -a -s l-test5
      20180211:15:30:55:019592 gpinitstandby:l-test6:gpadmin-[INFO]:-Validating environment and parameters for standby initialization...
      20180211:15:30:55:019592 gpinitstandby:l-test6:gpadmin-[INFO]:-Checking for filespace directory /export/gp_data/master/gpseg-1 on l-test5
      20180211:15:30:55:019592 gpinitstandby:l-test6:gpadmin-[INFO]:------------------------------------------------------
      20180211:15:30:55:019592 gpinitstandby:l-test6:gpadmin-[INFO]:-Greenplum standby master initialization parameters
      20180211:15:30:55:019592 gpinitstandby:l-test6:gpadmin-[INFO]:------------------------------------------------------
      20180211:15:30:55:019592 gpinitstandby:l-test6:gpadmin-[INFO]:-Greenplum master hostname               = l-test6
      20180211:15:30:55:019592 gpinitstandby:l-test6:gpadmin-[INFO]:-Greenplum master data directory         = /export/gp_data/master/gpseg-1
      20180211:15:30:55:019592 gpinitstandby:l-test6:gpadmin-[INFO]:-Greenplum master port                   = 65432
      20180211:15:30:55:019592 gpinitstandby:l-test6:gpadmin-[INFO]:-Greenplum standby master hostname       = l-test5
      20180211:15:30:55:019592 gpinitstandby:l-test6:gpadmin-[INFO]:-Greenplum standby master port           = 65432
      20180211:15:30:55:019592 gpinitstandby:l-test6:gpadmin-[INFO]:-Greenplum standby master data directory = /export/gp_data/master/gpseg-1
      20180211:15:30:55:019592 gpinitstandby:l-test6:gpadmin-[INFO]:-Greenplum update system catalog         = On
      .
      .
      ```

### standby 节点故障

当standby节点服务器恢复后，需要将standby节点删除，然后重新初始化一下standby服务器即可

1. 删除故障的standby节点

   ```shell
   [gpadmin@l-test5 ~]$ gpinitstandby -r -a
   20180209:16:52:04:011917 gpinitstandby:l-test5:gpadmin-[INFO]:------------------------------------------------------
   20180209:16:52:04:011917 gpinitstandby:l-test5:gpadmin-[INFO]:-Warm master standby removal parameters
   20180209:16:52:04:011917 gpinitstandby:l-test5:gpadmin-[INFO]:------------------------------------------------------
   20180209:16:52:04:011917 gpinitstandby:l-test5:gpadmin-[INFO]:-Greenplum master hostname               = l-test5
   20180209:16:52:04:011917 gpinitstandby:l-test5:gpadmin-[INFO]:-Greenplum master data directory         = /export/gp_data/master/gpseg-1
   20180209:16:52:04:011917 gpinitstandby:l-test5:gpadmin-[INFO]:-Greenplum master port                   = 65432
   20180209:16:52:04:011917 gpinitstandby:l-test5:gpadmin-[INFO]:-Greenplum standby master hostname       = l-test6
   20180209:16:52:04:011917 gpinitstandby:l-test5:gpadmin-[INFO]:-Greenplum standby master port           = 65432
   20180209:16:52:04:011917 gpinitstandby:l-test5:gpadmin-[INFO]:-Greenplum standby master data directory = /export/gp_data/master/gpseg-1
   20180209:16:52:18:011917 gpinitstandby:l-test5:gpadmin-[INFO]:-Removing standby master from catalog...
   20180209:16:52:18:011917 gpinitstandby:l-test5:gpadmin-[INFO]:-Database catalog updated successfully.
   20180209:16:52:18:011917 gpinitstandby:l-test5:gpadmin-[INFO]:-Removing filespace directories on standby master...
   20180209:16:52:18:011917 gpinitstandby:l-test5:gpadmin-[INFO]:-Successfully removed standby master
   ```

2. 重新初始化standby节点

   ```shell
   [gpadmin@l-test5 ~]$ gpinitstandby -s l-test6 -a
   20180209:16:59:08:013723 gpinitstandby:l-test5:gpadmin-[INFO]:-Validating environment and parameters for standby initialization...
   20180209:16:59:08:013723 gpinitstandby:l-test5:gpadmin-[INFO]:-Checking for filespace directory /export/gp_data/master/gpseg-1 on l-test6
   20180209:16:59:08:013723 gpinitstandby:l-test5:gpadmin-[INFO]:------------------------------------------------------
   20180209:16:59:08:013723 gpinitstandby:l-test5:gpadmin-[INFO]:-Greenplum standby master initialization parameters
   20180209:16:59:08:013723 gpinitstandby:l-test5:gpadmin-[INFO]:------------------------------------------------------
   20180209:16:59:08:013723 gpinitstandby:l-test5:gpadmin-[INFO]:-Greenplum master hostname               = l-test5
   20180209:16:59:08:013723 gpinitstandby:l-test5:gpadmin-[INFO]:-Greenplum master data directory         = /export/gp_data/master/gpseg-1
   20180209:16:59:08:013723 gpinitstandby:l-test5:gpadmin-[INFO]:-Greenplum master port                   = 65432
   20180209:16:59:08:013723 gpinitstandby:l-test5:gpadmin-[INFO]:-Greenplum standby master hostname       = l-test6
   20180209:16:59:08:013723 gpinitstandby:l-test5:gpadmin-[INFO]:-Greenplum standby master port           = 65432
   20180209:16:59:08:013723 gpinitstandby:l-test5:gpadmin-[INFO]:-Greenplum standby master data directory = /export/gp_data/master/gpseg-1
   20180209:16:59:08:013723 gpinitstandby:l-test5:gpadmin-[INFO]:-Greenplum update system catalog         = On
   ```

3. 检查standby 的配置信息

   ```shell
   [gpadmin@l-test5 ~]$ gpstate -f
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:-Starting gpstate with args: -f
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:-local Greenplum Version: 'postgres (Greenplum Database) 5.4.1 build commit:4eb4d57ae59310522d53b5cce47aa505ed0d17d3'
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:-master Greenplum Version: 'PostgreSQL 8.3.23 (Greenplum Database 5.4.1 build commit:4eb4d57ae59310522d53b5cce47aa505ed0d17d3) on x86_64-pc-linux-gnu, compi
   	led by GCC gcc (GCC) 6.2.0, 64-bit compiled on Jan 22 2018 18:15:33'
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:-Obtaining Segment details from master...
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:-Standby master details
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:-----------------------
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:-   Standby address          = l-test6
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:-   Standby data directory   = /export/gp_data/master/gpseg-1
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:-   Standby port             = 65432
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:-   Standby PID              = 19057
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:-   Standby status           = Standby host passive
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:--------------------------------------------------------------
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:--pg_stat_replication
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:--------------------------------------------------------------
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:--WAL Sender State: streaming
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:--Sync state: sync
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:--Sent Location: 0/14000000
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:--Flush Location: 0/14000000
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:--Replay Location: 0/14000000
   20180209:16:59:18:013939 gpstate:l-test5:gpadmin-[INFO]:--------------------------------------------------------------
   ```

### segment 节点故障

当一个primary segment节点故障，那么它所对应的mirror segment节点会接替primary的状态，继续保证整个集群的数据完整性
当一个mirror segment节点出现故障，它不会影响整个集群的可用性，但是需要尽快修复，保证所有的primary segment都有备份
如果primary segment 和 它所对应的mirror segment 节点都出现故障，那么greenplum认为集群数据不完整，整个集群将不再提供服务，直到primary segment 或 mirror segment恢复

primary segment节点和mirror segment节点的故障修复方式是一样的，这里以mirror节点故障为例

1. 关闭一个节点

   ```shell
   [gpadmin@l-test7 ~]$ pg_ctl -D /export/gp_data/mirror/data4/gpseg23 stop -m fast
   	waiting for server to shut down.... done
   	server stopped
   
   --------master节点执行-------
   [gpadmin@l-test5 ~]$ gpstate 
   20180211:16:17:12:005738 gpstate:l-test5:gpadmin-[INFO]:-Starting gpstate with args: 
   20180211:16:17:12:005738 gpstate:l-test5:gpadmin-[INFO]:-local Greenplum Version: 'postgres (Greenplum Database) 5.4.1 build commit:4eb4d57ae59310522d53b5cce47aa505ed0d17d3'
   20180211:16:17:12:005738 gpstate:l-test5:gpadmin-[INFO]:-master Greenplum Version: 'PostgreSQL 8.3.23 (Greenplum Database 5.4.1 build commit:4eb4d57ae59310522d53b5cce47aa505ed0d17d3) on x86_64-pc-linux-gnu, compi
   	led by GCC gcc (GCC) 6.2.0, 64-bit compiled on Jan 22 2018 18:15:33'
   20180211:16:17:12:005738 gpstate:l-test5:gpadmin-[INFO]:-Obtaining Segment details from master...
   20180211:16:17:12:005738 gpstate:l-test5:gpadmin-[INFO]:-Gathering data from segments...
   .
   .
   .
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[INFO]:-----------------------------------------------------
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[INFO]:-   Mirror Segment Status
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[INFO]:-----------------------------------------------------
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[INFO]:-   Total mirror segments                                     = 24
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[INFO]:-   Total mirror segment valid (at master)                    = 23
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[WARNING]:-Total mirror segment failures (at master)                 = 1                      <<<<<<<<
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[WARNING]:-Total number of postmaster.pid files missing              = 1                      <<<<<<<<
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[INFO]:-   Total number of postmaster.pid files found                = 23
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[WARNING]:-Total number of postmaster.pid PIDs missing               = 1                      <<<<<<<<
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[INFO]:-   Total number of postmaster.pid PIDs found                 = 23
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[WARNING]:-Total number of /tmp lock files missing                   = 1                      <<<<<<<<
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[INFO]:-   Total number of /tmp lock files found                     = 23
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[WARNING]:-Total number postmaster processes missing                 = 1                      <<<<<<<<
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[INFO]:-   Total number postmaster processes found                   = 23
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[INFO]:-   Total number mirror segments acting as primary segments   = 0
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[INFO]:-   Total number mirror segments acting as mirror segments    = 24
   20180211:16:17:14:005738 gpstate:l-test5:gpadmin-[INFO]:-----------------------------------------------------
   ```

2. 开始修复故障节点

      ```shell
      [gpadmin@l-test5 ~]$ gprecoverseg -a
      .
      .
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-Greenplum instance recovery parameters
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:----------------------------------------------------------
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-Recovery type              = Standard
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:----------------------------------------------------------
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-Recovery 1 of 1
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:----------------------------------------------------------
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-   Synchronization mode                        = Incremental
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-   Failed instance host                        = l-test7
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-   Failed instance address                     = l-test7
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-   Failed instance directory                   = /export/gp_data/mirror/data4/gpseg23
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-   Failed instance port                        = 50003
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-   Failed instance replication port            = 51003
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-   Recovery Source instance host               = l-test9
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-   Recovery Source instance address            = l-test9
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-   Recovery Source instance directory          = /export/gp_data/primary/data4/gpseg23
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-   Recovery Source instance port               = 40003
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-   Recovery Source instance replication port   = 41003
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-   Recovery Target                             = in-place
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:----------------------------------------------------------
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-1 segment(s) to recover
      20180211:16:25:38:009108 gprecoverseg:l-test5:gpadmin-[INFO]:-Ensuring 1 failed segment(s) are stopped
      . 
      .
      ```
      
3. 检查集群修复状态
   
     ```shell
     
     ##一直等到Data Status 这个属性全部都是Synchronized即可进行下一步操作
     [gpadmin@l-test5 ~]$ gpstate -m
     .
     20180211:16:25:51:009237 gpstate:l-test5:gpadmin-[INFO]:-   Mirror              Datadir                                Port    Status    Data Status       
     20180211:16:25:51:009237 gpstate:l-test5:gpadmin-[INFO]:-   l-test11   /export/gp_data/mirror/data1/gpseg0    50000   Passive   Synchronized
     .
     .
     20180211:16:25:51:009237 gpstate:l-test5:gpadmin-[INFO]:-   l-test7    /export/gp_data/mirror/data4/gpseg23   50003   Passive   Resynchronizing
     20180211:16:25:51:009237 gpstate:l-test5:gpadmin-[INFO]:--------------------------------------------------------------
     
     [gpadmin@l-test5 ~]$ 
     [gpadmin@l-test5 ~]$ gpstate -m
     .
     .
     20180211:16:31:54:010763 gpstate:l-test5:gpadmin-[INFO]:--------------------------------------------------------------
     20180211:16:31:54:010763 gpstate:l-test5:gpadmin-[INFO]:-   Mirror              Datadir                                Port    Status    Data Status    
     20180211:16:31:54:010763 gpstate:l-test5:gpadmin-[INFO]:-   l-test11   /export/gp_data/mirror/data1/gpseg0    50000   Passive   Synchronized
     .
     .
     20180211:16:31:54:010763 gpstate:l-test5:gpadmin-[INFO]:-   l-test7    /export/gp_data/mirror/data4/gpseg23   50003   Passive   Synchronized
     20180211:16:31:54:010763 gpstate:l-test5:gpadmin-[INFO]:--------------------------------------------------------------
     
     ```
     
4. 检查集群修复状态(可选)
         
        ```shell
        [gpadmin@l-test5 ~]$ gprecoverseg -r
        ```
    

## 集群扩容

### 纵向拓展

在准备通过在每台机器上再增加1个节点，来扩容segment，简单的来说就是纵向扩容

```shell
1、添加需要扩容的主机
[gpadmin@gw_mdw1 ~]$ cat seg_hosts 
gw_sdw1
gw_sdw2
2、生成扩容配置文件

[gpadmin@gw_mdw1 ~]$ gpexpand -f seg_hosts
Would you like to initiate a new System Expansion Yy|Nn (default=N):
> y            <------确认添加

How many new primary segments per host do you want to add? (default=0):
> 1            <------每台机器上添加1个计算节点
Enter new primary data directory 1:
> /data/primary    <------增加的计算节点存放的目录

[gpadmin@gw_mdw1 ~]$ cat gpexpand_inputfile_20190327_231903 
gw_sdw1:gw_sdw1:40004:/data/primary/gpseg8:10:8:p
gw_sdw2:gw_sdw2:40004:/data/primary/gpseg9:11:9:p

3、执行扩容
[gpadmin@gw_mdw1 ~]$ gpexpand -i gpexpand_inputfile_20190327_231903
如果失败可使用gpexpand -r 回滚

4、数据重分布
[gpadmin@gw_mdw1 ~]$ gpexpand -a -S -t /tmp -v -n 1
```

1. 添加需要扩容的主机

```shell
[gpadmin@gw_mdw1 ~]$ cat seg_hosts 
gw_sdw1
gw_sdw2
```

2. 生成扩容配置文件

```shell
[gpadmin@gw_mdw1 ~]$ gpexpand -f seg_hosts
Would you like to initiate a new System Expansion Yy|Nn (default=N):
> y            <------确认添加

How many new primary segments per host do you want to add? (default=0):
> 1            <------每台机器上添加1个计算节点
Enter new primary data directory 1:
> /data/primary    <------增加的计算节点存放的目录

[gpadmin@gw_mdw1 ~]$ cat gpexpand_inputfile_20190327_231903 
gw_sdw1:gw_sdw1:40004:/data/primary/gpseg8:10:8:p
gw_sdw2:gw_sdw2:40004:/data/primary/gpseg9:11:9:p
```

3. 执行扩容

```shell
[gpadmin@gw_mdw1 ~]$ gpexpand -i gpexpand_inputfile_20190327_231903
如果失败可使用gpexpand -r 回滚
```

4. 数据重分布

```shell
[gpadmin@gw_mdw1 ~]$ gpexpand -a -S -t /tmp -v -n 1
```

### 横向拓展

这次我们不仅在每台机器上添加1个计算节点，还添加一个数据节点（也就是一个新机器）

1. 生成配置文件

```shell
[gpadmin@gw_mdw1 ~]$ cat seg_hosts 
gw_sdw1
gw_sdw2
gw_sdw3
```

2. 生成扩容配置文件

```shell
[gpadmin@gw_mdw1 ~]$ gpexpand -f seg_hosts
	
##生成文件如下：
##可以看到，虽然只是添加一个，greenplum查看到gw_sdw3上并没有一个节点，就自动为其一次添加6个，是它与其他两个机器数量一致
[gpadmin@gw_mdw1 ~]$ cat gpexpand_inputfile_20190328_014748 
gw_sdw3:gw_sdw3:40000:/data/primary/gpseg10:12:10:p
gw_sdw3:gw_sdw3:40001:/data/primary/gpseg11:13:11:p
gw_sdw3:gw_sdw3:40002:/data/primary/gpseg12:14:12:p
gw_sdw3:gw_sdw3:40003:/data/primary/gpseg13:15:13:p
gw_sdw3:gw_sdw3:40004:/data/primary/gpseg14:16:14:p
gw_sdw1:gw_sdw1:40005:/data/primary/gpseg15:17:15:p
gw_sdw2:gw_sdw2:40005:/data/primary/gpseg16:18:16:p
gw_sdw3:gw_sdw3:40005:/data/primary/gpseg17:19:17:p
```

3. 执行扩容

```shell
[gpadmin@gw_mdw1 ~]$ gpexpand -i gpexpand_inputfile_20190328_014748
```

4. 数据重分布

```shell
[gpadmin@gw_mdw1 ~]$ gpexpand -a -S -t /tmp -v -n 1
```

## 备份与恢复

### 备份

```shell
全量备份
gpbackup --dbname test1 --backup-dir /tmp --leaf-partition-data
增量备份
gpbackup --dbname test1 --backup-dir /tmp --leaf-partition-data --incremental
```

### 恢复

```shell
gprestore --backup-dir /tmp --timestamp 20200707144340 --redirect-db test2 --data-only --incremental
```



更多参考http://docs-cn.greenplum.org/v6/homenav.html