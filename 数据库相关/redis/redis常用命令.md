#### Redis集群相关命令

##### Redis集群创建添加

```shell
创建集群
	redis-cli --cluster create 192.168.1.1:6379 \
	192.168.1.2:6379 \
	192.168.1.3:6379 \
	192.168.1.4:6379 \
	192.168.1.5:6379 \
	192.168.1.6:6379 \
	--cluster-replicas 1
查看集群节点
	redis-cli --cluster info 192.168.1.1:6379
查看集群节点
	redis-cli cluster nodes
	redis-cli cluster slots
新增节点
	redis-cli --cluster add-node 192.168.1.7:6379 192.168.1.1:6379
	redis-cli --cluster add-node 192.168.1.8:6379 192.168.1.1:6379
为master节点添加分片
	redis-cli --cluster reshard 192.168.1.7:6379
	How many slots do you want to move (from 1 to 16384)? 500
	#这里填写分配多少个槽给5007
	What is the receiving node ID? 63aa476d990dfa9f5f40eeeaa0315e7f9948554d
	#这里添加接收节点的ID，我们填写5007服务节点的ID
	Please enter all the source node IDs.
	Type 'all' to use all the nodes as source nodes for the hash slots.
	Type 'done' once you entered all the source nodes IDs.
	Source node #1: all
	#这里填写槽的来源，all表示是所有服务节点
设置从节点
	先登录192.168.1.8服务节点
	指定192.168.1.8从节点的主节点ID,这里我们填写192.168.1.7服务节点ID
	cluster replicate 63aa476d990dfa9f5f40eeeaa0315e7f9948554d
		
```

##### Redis集群key操作

```shell
获取所有key
	redis-cli -c --cluster call 192.168.1.1:6379  keys \*
```



