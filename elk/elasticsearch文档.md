## 常用接口

### 集群相关

- 集群健康状态
  
  ```shell
  GET _cluster/health?pretty
  ```

- 集群状态信息
  
  ```shell
  GET _cluster/stats
  ```

- 查看节点信息
  
  ```shell
  GET _cat/nodes?pretty
  ```

- 获取集群参数
  
  ```shell
  GET _cluster/settings
  ```

- 集群参数配置
  
  ```shell
  PUT _cluster/settings
  {
      "persistent": {
          "cluster.routing.allocation.enable": "none"
      }
  }
  ```

- 查看集群阻塞任务
  
  ```shell
  GET _cat/pending_tasks
  ```

- 移除一个节点
  
  ```shell
  PUT _cluster/settings
  {
    "transient" : {
      "cluster.routing.allocation.exclude._name" : "node-2"
    }
  }
  ```



### 索引相关

- 查看索引信息
  
  ```shell
  GET _cat/indices
  ```

- 删除索引
  
  ```shell
  DELETE ${indexname}
  ```

- 关闭索引
  
  ```shell
  POST ${indexname}/_close
  ```

- 打开索引
  
  ```shell
  POST ${indexname}/_open
  ```

- 冻结索引(6.6.0以上版本)
  
  ```shell
  POST ${indexname}/_freeze
  ```

- 冻结索引(6.6.0以上版本)
  
  ```shell
  POST ${indexname}/_unfreeze
  ```

- 迁移分片
  
  ```shell
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

## 索引生命周期

- 创建生命周期策略
  
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

- 创建索引模板
  
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
      "index.lifecycle.name": "test"
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
        "number_of_replicas":1
        "index.max_docvalue_fields_search":500,
        "refresh_interval" : "30s",
        "index.lifecycle.name": "test"
      }
    }
  }
  ```

- 将生命周期和索引模板关联
  
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

- 创建带别名的索引
  
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