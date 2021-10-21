#### 一、常用的kubectl命令

命令格式

```shell
kubectl [command]  [TYPE]  [NAME] [flags]
上面的命令是： kubectl命令行中，指定执行什么操作（command），指定什么类型资源对象（type），指定此类型的资源对象名称（name）,指定可选参数（flags）,后面的参数就是为了修饰那个唯一的对象
```

列出命名空间

```shell
[root@k8s-master1 ~]# kubectl get namespace
NAME              STATUS   AGE
default           Active   4d11h
kube-node-lease   Active   4d11h
kube-public       Active   4d11h
kube-system       Active   4d11h
```

列出可用资源

```	shell
[root@k8s-master1 ~]# kubectl get deployments --all-namespaces
NAMESPACE     NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
kube-system   calico-kube-controllers   1/1     1            1           4d11h
kube-system   coredns                   2/2     2            2           3d17h
kube-system   metrics-server            1/1     1            1           3d17h
[root@k8s-master1 ~]# kubectl get StorageClass
No resources found.
```

显示有关资源的详细信息

```shell
kubectl describe pod nvjob-lnrxj -n default
```

从 Pod 中的容器打印日志

```shell
kubectl logs <pod_name> -n <namespace>
```

在 Pod 中的容器执行命令

```shell
kubectl exec <pod_name> -n <namespace> date
kubectl delete pod <pod_name> -n <namespace>
```

强制重启pod

```shell
kubectl get pod -n {namespace} {podname} -o yaml | kubectl replace --force -f -
```

强制重新部署

```shell
kubectl get deployments -n  {namespace} {deploymentsname} -o yaml | kubectl replace --force -f -
```

通过yaml文件创建

```shell
kubectl create -f xxx.yaml （不建议使用，无法更新，必须先delete）
kubectl apply -f xxx.yaml（创建+更新，可以重复使用）
```

通过yaml文件删除

```shell
kubectl delete -f xxx.yaml
```

#### 二、k8s yaml相关
通过变量获取容器相关信息

```	yaml
env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
```

> 关于引用使用$()引用时适合用于cmd启动参数，同时可在pod启动后使用${}引用环境变量

**calico单个pod固定IP多pod固定ip池**

calicoctl安装

```shell
# cd /usr/local/bin/
# curl -O -L  https://github.com/projectcalico/calicoctl/releases/download/v3.10.1/calicoctl
# chmod +x calicoctl
# mkdir /etc/calico
# vim /etc/calico/calicoctl.cfg
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  datastoreType: "kubernetes"
  kubeconfig: "/root/.kube/config"
```

主要利用`calico`组件的两个`kubernetes`注解:

1)`cni.projectcalico.org/ipAddrs`

2)`cni.projectcalico.org/ipv4pools`

*单个pod固定IP*

```yaml
kind: Deployment
metadata:
  labels:
    app: test-app
  name: test-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      annotations:
        cni.projectcalico.org/ipAddrs: '["10.244.24.71"]'

```

*多个pod固定IP池*

需要创建额外IP池（除了默认IP池）。利用注解`cni.projectcalico.org/ipv4pools`。

```shell
[root@k8s-master3 ~]# cat test-ippool.yaml 
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: test-ippool
spec:
  blockSize: 31
  cidr: 10.245.100.0/31
  ipipMode: Never
  natOutgoing: true
[root@k8s-master3 ~]# calicoctl create -f test-ippool.yaml 
Successfully created 1 'IPPool' resource(s)
[root@k8s-master3 ~]# cat nginx.yaml 
apiVersion: apps/v1 # for versions before 1.9.0 use apps/v1beta2
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2
  template:
    metadata:
      labels:
        app: nginx
      annotations:
        cni.projectcalico.org/ipv4pools: '["test-ippool"]'
    spec:
      containers:
      - name: nginx
        image: nginx:1.7.9
        ports:
        - containerPort: 80
[root@k8s-master3 ~]# kubectl create -f nginx.yaml 
```

> 此方法仅限于calico网络插件

#### 三、节点维护

设置节点不可调度

```shell
[root@k8s-master1 ~]# kubectl cordon k8s-worker1
node/k8s-worker1 cordoned
[root@k8s-master1 ~]# kubectl get node
NAME          STATUS                     ROLES    AGE     VERSION
k8s-master1   Ready                      master   4d11h   v1.15.6
k8s-master2   Ready                      master   4d11h   v1.15.6
k8s-worker1   Ready,SchedulingDisabled   node     4d11h   v1.15.6
k8s-worker2   Ready 
```

驱逐节点上的pod

```shell
[root@k8s-master1 ~]# kubectl drain k8s-worker1 --delete-local-data --ignore-daemonsets --force
node/k8s-worker1 already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/calico-node-5lwz9
evicting pod "metrics-server-5889d65c57-2fhlx"
evicting pod "coredns-869d79f7f7-mxssg"
pod/coredns-869d79f7f7-mxssg evicted
pod/metrics-server-5889d65c57-2fhlx evicted
node/k8s-worker1 evicted
```

维护结束

```shell
[root@k8s-master1 ~]# kubectl uncordon k8s-worker1
node/k8s-worker1 uncordoned
[root@k8s-master1 ~]# kubectl get node
NAME          STATUS   ROLES    AGE     VERSION
k8s-master1   Ready    master   4d11h   v1.15.6
k8s-master2   Ready    master   4d11h   v1.15.6
k8s-worker1   Ready    node     4d11h   v1.15.6
k8s-worker2   Ready    node     4d11h   v1.15.6
```

