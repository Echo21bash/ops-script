### 关于zookeeper集群部署的说明
* 其包含了两种部署zookeeper集群的方式：StatefulSet和Service&Deployment
* 两种方式各有优劣，对于像Redis、Mongodb、Zookeeper等有状态的服务，使用StatefulSet是首选方式。

### StatefulSet方式
 1. 部署及创建可用的PV存储
 		kubectl apply -f zk-my-statefulset.yaml

		
### Deployment方式
 1. 部署及创建可用的PV存储
 		kubectl apply -f zk-my-deployment.yaml

### 关于zookeeper集群部署参数默认值
```shell
    CLIENT_PORT=2181
    SERVER_PORT=2888
    ELECTION_PORT=3888
    TICK_TIME=2000
    INIT_LIMIT=10
    SYNC_LIMIT=5
    HEAP=512M
    MAX_CLIENT_CNXNS=60
    SNAP_RETAIN_COUNT=3
    PURGE_INTERVAL=0
    MIN_SESSION_TIMEOUT=TICK_TIME*2
    MAX_SESSION_TIMEOUT=TICK_TIME*20
    SERVERS=1
```
