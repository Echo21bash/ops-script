# Nodejs知识库

## 依赖安装

### 权限问题

```shell
#增加参数--unsafe-perm
npm install --unsafe-perm
#一劳永逸的方法
#针对当前用户
npm config set unsafe-perm
#全局
npm config -g set unsafe-perm
```

### 网络问题

> npm默认下载地址也是从国外的网站https://registry.npmjs.org/ 下载速度比较慢。还有如果你安装的模块依赖了 C++ 模块需要编译, 肯定会通过 `node-gyp` 来编译,`node-gyp` 在第一次编译的时候, 需要依赖 node 源代码, 于是又会去 http://nodejs.org/dist/下载

```shell
npm config -g set registry https://registry.npmmirror.com
npm config -g set disturl https://npmmirror.com/mirrors/node
```

### 其他报错

> cnpm错误：“Error：Cannot find module ‘fs/promises”

```shell
解决方案：
1、升级Node.js版本：
清理npm缓存：npm cache clean -f
安装版本管理工具：npm install -g n
升级到最新的版本：n latest（最新版本）n stable（最新稳定版本）
2、降低cnpm的版本：
删除已安装的cnpm版本：npm uninstall -g cnpm
安装低版本cnpm：npm install cnpm@7.1.0 -g --registry=https://registry.npm.taobao.org
通过以上两种方式即可解决！
```

## pm2工具

### PM2 的主要特性

- 内建负载均衡（使用 Node cluster 集群模块）
- 后台运行
- 0 秒停机重载，我理解大概意思是维护升级的时候不需要停机.
- 具有 Ubuntu 和 CentOS 的启动脚本
- 停止不稳定的进程（避免无限循环）
- 控制台检测
- 提供 HTTP API
- 远程控制和实时的接口 API ( Nodejs 模块,允许和 PM2 进程管理器交互 )

### 安装

```shell
#全局安装pm2，依赖node和npm
npm install -g pm2
```

### 常用命令

```shell
pm2 start ./build/server.js
pm2 show (appname|id)
pm2 list
pm2 monit
pm2 logs
pm2 stop 0
pm2 stop all
```

### pm2日志切割

```shell
#安装
pm2 install pm2-logrotate
#配置切割参数
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:dateFormat YYYY-MM-DD_HH-mm-ss
pm2 set pm2-logrotate:workerInterval 30
pm2 set pm2-logrotate:rotateInterval 0 0 * * *
pm2 set pm2-logrotate:TZ Asia/Shanghai
```

## Cypress安装问题

### 问题描述

> 在使用npm或yarn安装时，已经正确配置NPM源，但是还是报错。

```shell
#由于网络问题使用npm或者yarn安装依赖时报如下错误
[05:24:51]  Downloading Cypress     [started]
[05:25:02]  Downloading Cypress     [failed]
The Cypress App could not be downloaded.

Does your workplace require a proxy to be used to access the Internet? If so, you must configure the HTTP_PROXY environment variable before downloading Cypress. Read more: https://on.cypress.io/proxy-configuration

Otherwise, please check network connectivity and try again:

----------

URL: https://download.cypress.io/desktop/3.8.3?platform=linux&arch=x64
Error: read ECONNRESET
```

### 处理方案

```shell
#在使用npm或yarn安装时，除了NPM源，还需要一个URL下载二进制文件
export CYPRESS_INSTALL_BINARY=https://repo.huaweicloud.com/cypress/3.8.3/linux-x64/cypress.zip
#或者使用本地文件
export CYPRESS_INSTALL_BINARY=/path/to/your/cypress.zip
##最后重新安装cypress
npm install cypress@3.8.3
```

