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
