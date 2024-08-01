# Minio对象存储

## 单节点双向同步

### 部署两台单节点

```shell
MINIO_ACCESS_KEY=ossadmin
MINIO_SECRET_KEY=ossadmin
minio server -C /opt/minio/etc --address :9000 /data/minio
```

### 配置节点信息

```shell
mc -C /opt/minio/etc config host add minio_1 http://10.1.13.68:9000 ossadmin ossadmin
mc -C /opt/minio/etc config host add minio_2 http://10.1.13.223:9000 ossadmin ossadmin
```

### 同步测试

```shell
##同步命令
/opt/minio/bin/mc -C /opt/minio/etc mirror --remove --overwrite --watch  minio_1  minio_2
##systemd服务
[Unit]
Description=startup minioc mirror slave to master
After=network.target
[Service]
Type=simple
ExecStart=/opt/minio/bin/mc -C /opt/minio/etc mirror --remove --overwrite --watch  minio_1  minio_2
Restart=on-failure
[Install]
WantedBy=multi-user.target
```

