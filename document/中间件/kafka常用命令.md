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

  
