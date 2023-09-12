# helm相关

## 基础命令

```shell
#查看版本
helm version
#查看部署的应用
helm list
#添加仓库
helm repo add bitnami https://charts.bitnami.com/bitnami
#更新repo仓库资源
helm repo update
#搜索包
helm search repo redis
#安装应用
helm install --name redis --namespaces prod bitnami/redis
#查看charts状态
helm status redis
#删除charts
helm delete --purge redis
#下载指定版本的chart包
helm pull bitnami/kafka --version 22.0.1
#将helm chart打包
helm package syslog-ng-chart/
#获取已经部署的values值
helm get values redis
```

