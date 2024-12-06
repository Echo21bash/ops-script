# Kafka知识库

## Kafka常用命令

### 集群相关

- 查询集群描述

  ```shell
  bin/kafka-topics.sh --describe --zookeeper 127.0.0.1:2181
  ```

- 压力测试

  ```shell
  bin/kafka-producer-perf-test.sh --topic test --num-records 100 --record-size 1 --throughput 100  --producer-props bootstrap.servers=localhost:9092
  ```

- 分区扩容

  ```shell
  ##kafka版本 < 2.2
  bin/kafka-topics.sh --zookeeper localhost:2181 --alter --topic topic1 --partitions 2
  ##kafka版本 >= 2.2
  bin/kafka-topics.sh --bootstrap-server localhost:9092 --alter --topic topic1 --partitions 2
  ```

- 迁移分区

  ```shell
  ##创建规则json
  
  cat > increase-replication-factor.json <<EOF
  {"version":1, "partitions":[
  {"topic":"__consumer_offsets","partition":0,"replicas":[0,1]},
  {"topic":"__consumer_offsets","partition":1,"replicas":[0,1]},
  {"topic":"__consumer_offsets","partition":2,"replicas":[0,1]},
  {"topic":"__consumer_offsets","partition":3,"replicas":[0,1]},
  {"topic":"__consumer_offsets","partition":4,"replicas":[0,1]},
  {"topic":"__consumer_offsets","partition":5,"replicas":[0,1]},
  {"topic":"__consumer_offsets","partition":6,"replicas":[0,1]},
  {"topic":"__consumer_offsets","partition":7,"replicas":[0,1]},
  {"topic":"__consumer_offsets","partition":8,"replicas":[0,1]},
  {"topic":"__consumer_offsets","partition":9,"replicas":[0,1]},
  {"topic":"__consumer_offsets","partition":10,"replicas":[0,1]},
  {"topic":"__consumer_offsets","partition":11,"replicas":[0,1]},
  {"topic":"__consumer_offsets","partition":12,"replicas":[0,1]},
  {"topic":"__consumer_offsets","partition":13,"replicas":[0,1]},
  {"topic":"__consumer_offsets","partition":14,"replicas":[0,1]},
  {"topic":"__consumer_offsets","partition":15,"replicas":[0,1]}]
  }
  EOF
  
  ##执行
  bin/kafka-reassign-partitions.sh --zookeeper localhost:2181 --reassignment-json-file increase-replication-factor.json --execute
  	
  ##验证
  bin/kafka-reassign-partitions.sh --zookeeper localhost:2181 --reassignment-json-file increase-replication-factor.json --verify
  ```

  

### Topic相关

- 创建topic

  ```shell
  bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 2 --partitions 4 --topic test
  ```

  ```shell
  ##kafka版本 >= 2.2 推荐
  bin/kafka-topics.sh --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic test
  ```

- 查看topic列表

  ```shell
  bin/kafka-topics.sh --zookeeper 127.0.0.1:2181 --list
  ##（支持0.9版本）
  bin/kafka-topics.sh --list --bootstrap-server localhost:9092
  
  #删除topic
  bin/kafka-topics.sh --delete --topic acc-backend-java --bootstrap-server localhost:9092
  ```

- 生产消息

  ```shell
  bin/kafka-console-producer.sh --broker-list localhost:9092 --topic test
  ```

- 消费消息

  ```shell
  bin/kafka-console-consumer.sh  --bootstrap-server localhost:9092 --from-beginning --topic test
  ```

- 重置offset

  ```shell
  ##所有topic
  bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group test --reset-offsets --all-topics --to-latest --execute
  ##指定主题
  bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group test --reset-offsets --topic test --to-latest --execute
  ##指定偏移量
  bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group test --reset-offsets --topic test --to-offset 1000 --execute
  ```

- 切换leader

  ```shell
  ##kafka版本 <= 2.4
  bin/kafka-preferred-replica-election.sh --zookeeper zk_host:port/chroot
  ##kafka新版本
  bin/kafka-preferred-replica-election.sh --bootstrap-server broker_host:port
  ```

- 查看消费组

  ```shell
  bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list
  bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --all-groups
  ```

- 显示某个消费组的消费详情

  ```shell
  ##仅支持offset存储在zookeeper上的
  bin/kafka-run-class.sh kafka.tools.ConsumerOffsetChecker --zookeeper localhost:2181 --group test
  bin/kafka-consumer-groups.sh --new-consumer --bootstrap-server localhost:9092 --describe --group test
  ##（0.9版本-0.10.1.0之间）
  bin/kafka-consumer-groups.sh --new-consumer --bootstrap-server localhost:9092 --describe --group test
  ##（0.10.1.0版本+）
  bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group test
  ```


* 删除消费组

  ```shell
  bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --delete --group test
  ```
  
* 删除消费组

  ```shell
  bin/kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092  --delete-offsets --group lzdt-itp-acc --topic lzdt-itp-order-pay-success
  ```

## 在线修改参数

### 修改 broker 的参数

```shell
#改变当前broker 0上的log cleaner threads可以通过下面命令实现：
bin/kafka-configs.sh --bootstrap-server localhost:9092 --entity-type brokers --entity-name 0 --alter --add-config log.cleaner.threads=2

#查看当前broker 0的动态配置参数：
bin/kafka-configs.sh --bootstrap-server localhost:9092 --entity-type brokers --entity-name 0 --describe

#删除broker id为0的server上的配置参数/设置为默认值：
bin/kafka-configs.sh --bootstrap-server localhost:9092 --entity-type brokers --entity-name 0 --alter --delete-config log.cleaner.threads

#同时更新集群上所有broker上的参数（cluster-wide类型，保持所有brokers上参数的一致性）：
bin/kafka-configs.sh --bootstrap-server localhost:9092 --entity-type brokers --entity-default --alter --add-config log.cleaner.threads=2

#查看当前集群中动态的cluster-wide类型的参数列表：
bin/kafka-configs.sh --bootstrap-server localhost:9092 --entity-type brokers --entity-default --describe
```

## Kafka认证

### 服务端配置

### 客户端配置

> 创建sasl配置文件

```shell
echo 'default.api.timeout.ms=600000
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="Gioneco@2023Abc";
' >client.properties
```

> 命令行添加参数指定配置文件--command-config

```shell
bin/kafka-topics.sh --list --bootstrap-server localhost:9092 --command-config ./client.properties
bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --command-config ./client.properties --list
bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --command-config ./client.properties --describe --group test
```



## Kafka常见问题

### 日志保留时间设置无效问题

> ​		看了网上很多文档，说是要设置log.retention.hour等等参数。默认是保留7天，但我实测下来发现日志根本没有任何变化。查看最早的消息还是7天的。
>
> ​		经过查找资料发现kafka只会回收上个分片的数据配置没有生效的原因就是，数据并没有达到分片触发条件，没有分片，所以没有回收。
>
> ​		kafka什么时候分片？按照大小分片和按照时间分片达到任意条件即可分片，有两个参数可以配置，log.roll.hours 设置多久滚动一次，滚动也就是之前的数据就会分片分出去，默认是144，log.segment.bytes 设置日志文件到了多大就会自动分片，默认是1GB。

```shell
#正确的必要配置，以下配置可以实现保留24h的kafka数据
log.retention.hours=24
log.roll.hours=24
```

### Rebalance

​		Rebalance 本质上是一种协议，规定了一个 Consumer Group 下的所有 consumer 如何达成一致，来分配订阅 Topic 的每个分区。

​    	例如：某 Group 下有 20 个 consumer 实例，它订阅了一个具有 100 个 partition 的 Topic 。正常情况下，kafka 会为每个 Consumer 平均的分配 5 个分区。这个分配的过程就是 Rebalance。

#### 触发 Rebalance 的时机
​	Rebalance 的触发条件有3个。

1. 组成员个数发生变化。例如有新的 consumer 实例加入该消费组或者离开组。

2. 订阅的 Topic 个数发生变化。

3. 订阅的 Topic 的分区数发生变化。

  

**Rebalance 发生时，Group 下所有 consumer 实例都会协调在一起共同参与，kafka 能够保证尽量达到最公平的分配。但是 Rebalance 过程对 consumer group 会造成比较严重的影响。在 Rebalance 的过程中 consumer group 下的所有消费者实例都会停止工作，等待 Rebalance 过程完成。**

#### 如何避免不必要的rebalance

​		要避免 Rebalance，还是要从 Rebalance 发生的时机入手。我们在前面说过，Rebalance 发生的时机有三个：

1. 组成员数量发生变化

2. 订阅主题数量发生变化

3. 订阅主题的分区数发生变化

​	**后两个我们可以人为的避免，发生rebalance最常见的原因是消费组成员的变化。**

​		消费者成员正常的添加和停掉导致rebalance，这种情况无法避免，但是时在某些情况下，Consumer 实例会被 Coordinator 错误地认为 “已停止” 从而被“踢出”Group。从而导致rebalance。

​		当 Consumer Group 完成 Rebalance 之后，每个 Consumer 实例都会定期地向 Coordinator 发送心跳请求，表明它还存活着。如果某个 Consumer 实例不能及时地发送这些心跳请求，Coordinator 就会认为该 Consumer 已经 “死” 了，从而将其从 Group 中移除，然后开启新一轮 Rebalance。这个时间可以通过Consumer 端的参数 session.timeout.ms进行配置。默认值是 10 秒。

​		除了这个参数，Consumer 还提供了一个控制发送心跳请求频率的参数，就是 heartbeat.interval.ms。这个值设置得越小，Consumer 实例发送心跳请求的频率就越高。频繁地发送心跳请求会额外消耗带宽资源，但好处是能够更加快速地知晓当前是否开启 Rebalance，因为，目前 Coordinator 通知各个 Consumer 实例开启 Rebalance 的方法，就是将 REBALANCE_NEEDED 标志封装进心跳请求的响应体中。

​		除了以上两个参数，Consumer 端还有一个参数，用于控制 Consumer 实际消费能力对 Rebalance 的影响，即 max.poll.interval.ms 参数。它限定了 Consumer 端应用程序两次调用 poll 方法的最大时间间隔。它的默认值是 5 分钟，表示你的 Consumer 程序如果在 5 分钟之内无法消费完 poll 方法返回的消息，那么 Consumer 会主动发起 “离开组” 的请求，Coordinator 也会开启新一轮 Rebalance。
