# clickhouse

## 集群搭建

> ClickHouse是一个分布式数据库管理系统，它可以通过分片（Shard）和副本（Replica）实现数据的高可用性和高扩展性。
>
> 分片是指将数据库中的数据分散存储到不同的节点上，以提高数据处理的并行能力。副本是指在分片的基础上，每个分片可以有多个副本来提供高可用性。
>
> 在配置ClickHouse集群时，你需要定义一个集群的配置，其中包括分片和副本的相关信息。以下是一个配置三分片和两副本的示例：

### 配置示例

```xml
<yandex>
    <clickhouse_remote_servers>
        <cluster_name>
            <!-- 配置分片1的副本 -->
            <shard>
                    <weight>1</weight>
                    <internal_replication>true</internal_replication>
                <replica>
                    <host>example-host-1</host>
                    <port>9000</port>
                    <user>default</user>
                    <password>aaAA11__</password>
                </replica>
                <replica>
                    <host>example-host-2</host>
                    <port>9002</port>
                    <user>default</user>
                    <password>aaAA11__</password>
                </replica>
            </shard>
            <!-- 配置分片2的副本 -->
            <shard>
                    <weight>1</weight>
                    <internal_replication>true</internal_replication>
                <replica>
                    <host>example-host-3</host>
                    <port>9000</port>
                    <user>default</user>
                    <password>aaAA11__</password>
                </replica>
                <replica>
                    <host>example-host-4</host>
                    <port>9002</port>
                    <user>default</user>
                    <password>aaAA11__</password>
                </replica>
            </shard>
            <!-- 配置分片3的副本 -->
            <shard>
                    <weight>1</weight>
                    <internal_replication>true</internal_replication>
                <replica>
                    <host>example-host-5</host>
                    <port>9000</port>
                    <user>default</user>
                    <password>aaAA11__</password>
                </replica>
                <replica>
                    <host>example-host-6</host>
                    <port>9002</port>
                    <user>default</user>
                    <password>aaAA11__</password>
                </replica>
            </shard>
        </cluster_name>
    </clickhouse_remote_servers>
    
    <!-- zookeeper配置 -->
    <zookeeper>
        <node>
            <host>example-zookeeper1</host>
            <port>2181</port>
        </node>
        <node>
            <host>example-zookeeper2</host>
            <port>2181</port>
        </node>
        <node>
            <host>example-zookeeper3</host>
            <port>2181</port>
        </node>
    </zookeeper>
    <!-- 变量配置互为副本的shard编号一致，layer为固定两级分片层级保持一致即可，replica为节点名称 -->
    <macros>
        <shard>01</shard>
        <layer>01</layer>
        <replica>example-host-1</replica>
    </macros>
</yandex>
```

```shell
# 主机名解析配置
[root@ch1 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
20.9.1.27 ch1
20.9.1.28 ch2
20.9.1.29 ch3
20.9.1.30 ch4
20.9.1.31 ch5
20.9.1.32 ch5
```



### 状态检查

```sql
---查询集群信息
SELECT * FROM system.clusters;

---查询分片标识符shard和副本标识符replica
select * from system.macros;

---查询zookeeper数据
SELECT * FROM system.zookeeper where path = '/clickhouse/tables';
 
---查询
SELECT * FROM system.replicas WHERE database = 'ADS';
```

## 表引擎介绍

> MergeTree和Distributed是ClickHouse表引擎中最重要，也是最常使用的两个引擎，本文将重点进行介绍。

### MergeTree系列引擎

MergeTree用于高负载任务的最通用和功能最强大的表引擎，其主要有以下关键特征：

- 基于分区键（partitioning key）的数据分区分块存储
- 数据索引排序（基于primary key和order by）
- 支持数据复制（带Replicated前缀的表引擎）
- 支持数据抽样

在写入数据时，该系列引擎表会按照分区键将数据分成不同的文件夹，文件夹内每列数据为不同的独立文件，以及创建数据的序列化索引排序记录文件。该结构使得数据读取时能够减少数据检索时的数据量，极大的提高查询效率。

该类型的引擎：

- [MergeTree](https://clickhouse.com/docs/zh/engines/table-engines/mergetree-family/mergetree#mergetree)
- [ReplacingMergeTree](https://clickhouse.com/docs/zh/engines/table-engines/mergetree-family/replacingmergetree#replacingmergetree)
- [SummingMergeTree](https://clickhouse.com/docs/zh/engines/table-engines/mergetree-family/summingmergetree#summingmergetree)
- [AggregatingMergeTree](https://clickhouse.com/docs/zh/engines/table-engines/mergetree-family/aggregatingmergetree#aggregatingmergetree)
- [CollapsingMergeTree](https://clickhouse.com/docs/zh/engines/table-engines/mergetree-family/collapsingmergetree#table_engine-collapsingmergetree)
- [VersionedCollapsingMergeTree](https://clickhouse.com/docs/zh/engines/table-engines/mergetree-family/versionedcollapsingmergetree#versionedcollapsingmergetree)
- [GraphiteMergeTree](https://clickhouse.com/docs/zh/engines/table-engines/mergetree-family/graphitemergetree#graphitemergetree)

#### 复制表

作为数据副本的主要实现载体，`ReplicatedMergeTree`在设计上有一些显著特点。

- **依赖ZooKeeper**：在执行`INSERT`和`ALTER`查询的时候，`ReplicatedMergeTree`需要借助`ZooKeeper`的分布式协同能力，以实现多个副本之间的同步。但是在查询副本的时候，并不需要使用`ZooKeeper`。
- **表级别的副本**：副本是在表级别定义的，所以每张表的副本配置都可以按照它的实际需求进行个性化定义，包括副本的数量，以及副本在集群内的分布位置等。
- **多主架构**（Multi Master）：**可以在任意一个副本上执行INSERT和ALTER查询，它们的效果是相同的**。这些操作会借助`ZooKeeper`的协同能力被分发至每个副本以本地形式执行。
- **Block数据块**：在执行`INSERT`命令写入数据时，会依据`max_insert_block_size`的大小（默认`1048576`行）将数据切分成若干个`Block`数据块。所以`Block`数据块是数据写入的基本单元，并且具有写入的原子性和唯一性。
- **原子性**：在数据写入时，一个`Block`块内的数据要么全部写入成功，要么全部失败。
- **唯一性**：在写入一个`Block`数据块的时候，会按照当前`Block`数据块的数据顺序、数据行和数据大小等指标，计算Hash信息摘要并记录在案。在此之后，如果某个待写入的`Block`数据块与先前已被写入的`Block`数据块拥有相同的Hash摘要（`Block`数据块内数据顺序、数据大小和数据行均相同），则该`Block`数据块会被忽略。这项设计可以预防由异常原因引起的`Block`数据块重复写入的问题。

```sql
--先创建一个表名为test的ReplicatedMergeTree本地表
CREATE TABLE default.test ON CLUSTER default_cluster_1
(
    `EventDate` DateTime, 
    `id` UInt64
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/default/test', '{replica}')
PARTITION BY toYYYYMM(EventDate)
ORDER BY id
```

其中：

- `/clickhouse/tables/`是约定俗成的路径固定前缀，表示zookeeper存放数据表的根路径。
- `{shard}`表示分片编号，通常用数值替代，例如01、02、03。一张数据表可以有多个分片，而每个分片都拥有自己的副本。
- `test`表示数据表的名称，为了方便维护，通常与物理表的名字相同（虽然ClickHouse并不强制要求路径中的表名称和物理表名相同）；
- `{replica}`表示副本名称，配置文件中指定；

* 使用副本的好处甚多。**首先，由于增加了数据的冗余存储，所以降低了数据丢失的风险；其次，由于副本采用了多主架构，所以每个副本实例都可以作为数据读、写的入口，这无疑分摊了节点的负载。**

> 特别注意：
>
> * 对于`zk_path`而言，同一张数据表的同一个分片的不同副本，应该定义相同的路径，shard字段配置一致；
> * 而对于`replica`而言，同一张数据表的同一个分片的不同副本，应该定义不同的名称

* 建表涉及的变量需要在配置文件中指定

```xml
<macros>
    <layer>05</layer>
    <shard>02</shard>
    <replica>example05-02-1</replica>
</macros>
```



### Distributed表引擎

Distributed表引擎本身不存储任何数据，而是作为数据分片的透明代理，能够自动路由数据到集群中的各个节点，分布式表需要和其他本地数据表一起协同工作。分布式表会将接收到的读写任务分发到各个本地表，而实际上数据的存储在各个节点的本地表中。

```sql
--基于本地表test创建表名为test_all的Distributed表
CREATE TABLE default.test_all ON CLUSTER default_cluster_1
(
    `EventDate` DateTime, 
    `id` UInt64
)
ENGINE = Distributed(default_cluster_1, default, test, rand())
```



**分布式表创建规则：**

- 创建Distributed表时需加上**on cluster** *cluster_name*，这样建表语句在某一个ClickHouse实例上执行一次即可分发到集群中所有实例上执行。
- 分布式表通常以本地表加“_all”命名。它与本地表形成一对多的映射关系，之后可以通过分布式表代理操作多张本地表。
- 分布式表的表结构尽量和本地表的结构一致。如果不一致，在建表时不会报错，但在查询或者插入时可能会抛出异常。



## 参数优化

> 在/etc/clickhouse-server/users.xml中修改调整max_partitions_per_insert_block

## 集群维护

### 表维护

```sql
---查看数据库容量、行数、压缩率
SELECT 
    sum(rows) AS `总行数`,
    formatReadableSize(sum(data_uncompressed_bytes)) AS `原始大小`,
    formatReadableSize(sum(data_compressed_bytes)) AS `压缩大小`,
    round((sum(data_compressed_bytes) / sum(data_uncompressed_bytes)) * 100, 0) AS `压缩率`
FROM system.parts;

---查看数据表容量、行数、压缩率
SELECT
    table AS `表名`,
    sum(rows) AS `总行数`,
    formatReadableSize(sum(data_uncompressed_bytes)) AS `原始大小`,
    formatReadableSize(sum(data_compressed_bytes)) AS `压缩大小`,
    round((sum(data_compressed_bytes) / sum(data_uncompressed_bytes)) * 100, 0) AS `压缩率`
FROM system.parts
GROUP BY table;

---查看数据表分区信息
SELECT 
    partition AS `分区`,
    sum(rows) AS `总行数`,
    formatReadableSize(sum(data_uncompressed_bytes)) AS `原始大小`,
    formatReadableSize(sum(data_compressed_bytes)) AS `压缩大小`,
    round((sum(data_compressed_bytes) / sum(data_uncompressed_bytes)) * 100, 0) AS `压缩率`
FROM system.parts
GROUP BY partition
ORDER BY partition ASC



SELECT *
FROM
    system.replicas
WHERE
    database = 'ADS'
```

## 集群监控

> clickhouse支持Prometheus监控，打开如下配置即可后，在Prometheus添加job即可，Grafana图表ID14192，导入即可看到监控指标。

```xml
    <prometheus>
        <endpoint>/metrics</endpoint>
        <port>9363</port>

        <metrics>true</metrics>
        <events>true</events>
        <asynchronous_metrics>true</asynchronous_metrics>
    </prometheus>
```

