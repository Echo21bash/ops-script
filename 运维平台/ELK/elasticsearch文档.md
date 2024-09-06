# Elasticsearch汇总

## 常用接口

### 集群相关

```shell
#集群健康状态
GET _cluster/health?pretty

#集群状态信息
GET _cluster/stats

#查看节点信息
GET _cat/nodes?pretty

#获取集群参数
GET _cluster/settings

#查看集群阻塞任务
GET _cat/pending_tasks

#配置集群参数示例
PUT _cluster/settings
{
  "persistent": {
    "cluster.routing.allocation.enable": "none"
  }
}
#每个节点分片数量
PUT /_cluster/settings
{
  "persistent": {
    "cluster.max_shards_per_node":10000
  }
}

#迁移索引
POST /_cluster/reroute
{
  "commands": [
    {
      "move": {
        "index": "test", "shard": 0,
        "from_node": "node1", "to_node": "node2"
      }
    }
  ]
}
```



### 索引相关

```shell
#查看索引信息
GET _cat/indices
#删除索引
DELETE ${indexname}
#关闭索引
POST ${indexname}/_close
#打开索引
POST ${indexname}/_open
#冻结索引(6.6.0以上版本)
POST ${indexname}/_freeze
#解冻索引(6.6.0以上版本)
POST ${indexname}/_unfreeze
```



## 索引生命周期

### 创建生命周期策略

```shell
PUT /_ilm/policy/test
{
  "policy": {                       
    "phases": {
      "hot": {                      
        "actions": {
              "rollover":{
                  "max_docs":1
              }
        }
      },
      "delete": {
        "min_age": "60s",           
        "actions": {
          "delete": {}              
        }
      }
    }
  }
}
```

### 创建索引模板

```shell
小于7.8
PUT /_template/logstash
{
  "index_patterns": ["test-*"],
  "settings":{
    "number_of_shards":3,
    "number_of_replicas":1,
    "index.max_docvalue_fields_search":500,
    "refresh_interval" : "30s",
    "index.lifecycle.name": "test", ##绑定生命周期策略
    "index.lifecycle.rollover_alias": "test" ##配置索引滚动别名
  }
}
```

```shell
7.8+（旧接口即将放弃，但仍可用）
PUT /_index_template/logstash
{
  "index_patterns": ["cdisp-*", "tyacc-*"],
  "template": {
    "settings": {
      "number_of_shards":3,
      "number_of_replicas":1,
      "index.max_docvalue_fields_search":500,
      "refresh_interval" : "30s",
      "index.lifecycle.name": "test", ##绑定生命周期策略
      "index.lifecycle.rollover_alias": "test" ##配置索引滚动别名
    }
  }
}
```

### 将生命周期和索引关联(可选)

```shell
PUT test-index
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 1,
    "index.lifecycle.name": "test"
  }
}
PUT test-*/_settings
{
  "index": {
    "lifecycle": {
        "name": "test"
    }
  }
}
```

### 创建带别名的索引

```shell
PUT test-000001
{
  "aliases": {
    "test":{
      "is_write_index": true 
     }
   }
}
```

## 集群维护

### 安全重启节点

- 暂停集群的shard自动均衡
  
  ```shell
  PUT _cluster/settings
  {
      "persistent": {
          "cluster.routing.allocation.enable": "none"
      }
  }
  ```

- 执行同步刷新
  
  ```shell
  POST _flush/synced
  ```

- 停止节点
  
  ```shell
  systemctl stop elasticsearch
  ```

- 启动节点
  
  ```shell
  systemctl start elasticsearch
  ```

- 启动集群的shard自动均衡
  
  ```shell
  PUT _cluster/settings
  {
      "persistent": {
          "cluster.routing.allocation.enable": "all"
      }
  }
  ```

- 分片恢复速度控制
  
  ```shell
  PUT _cluster/settings
  {
      "persistent": {
          "cluster.routing.allocation.node_concurrent_recoveries": 16,
          "indices.recovery.max_bytes_per_sec": "160mb"
      }
  }
  ```

## 配置相关

### 认证相关

```shell
#6.3.0版本之前需要自己手动安装插件，之后的版本已经默认安装
#创建ssl证书
./bin/elasticsearch-certutil ca
./bin/elasticsearch-certutil cert --ca elastic-stack-ca.p12
#将生成的证书文件，移动到 config 目录下
#安全认证配置示例
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.license.self_generated.type: basic
xpack.security.transport.ssl.verification_mode: certificate	xpack.security.transport.ssl.keystore.path: elastic-certificates.p12	xpack.security.transport.ssl.truststore.path: elastic-certificates.p12
	
#然后重启ES
#配置用户名密码
./bin/elasticsearch-setup-passwords interactive
```

## 问题处理

### 权限问题

> 在删除kibana相关系统索引时报无权限

```shell
### 使用管理员创建角色
curl -XPUT -u "elastic:4J0e08cHe6x7On97Q2crm6fK"  -H 'Content-Type: application/json' -k 'http://20.9.201.15:30920/_security/role/grant_kibana_system_indices' -d '
{
  "indices": [{
    "names": [".kibana*"],
    "privileges": ["all"],
    "allow_restricted_indices": true
  }]
}'

###为该角色创建用户
curl -XPUT -u "elastic:4J0e08cHe6x7On97Q2crm6fK"  -H 'Content-Type: application/json' -k 'http://20.9.201.15:30920/_security/user/temporarykibanasuperuser' -d '
{
  "password" : "l0ng-r4nd0m-p@ssw0rd",
  "roles" : [ "superuser", "grant_kibana_system_indices" ]
}'

###再次删除
curl -X DELETE -H "Content-Type: application/json" -u "temporarykibanasuperuser:l0ng-r4nd0m-p@ssw0rd" -k http://20.9.201.15:30920/.kibana_task_manager_8.2.3_001
```

