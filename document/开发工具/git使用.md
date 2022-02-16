# GIT使用

## GIT升级

- CentOS
  
  ```shell
  yum install http://opensource.wandisco.com/centos/6/git/x86_64/wandisco-git-release-6-1.noarch.rpm
  - or -
  yum install http://opensource.wandisco.com/centos/7/git/x86_64/wandisco-git-release-7-1.noarch.rpm
  - or -
  yum install http://opensource.wandisco.com/centos/7/git/x86_64/wandisco-git-release-7-2.noarch.rpm
  yum install git
  git --version
  ```

## 网络代理

- 查看当前代理设置
  
  ```shell
  git config --global http.proxy
  git config --global https.proxy
  ```

- 设置http代理
  
  ```shell
  git config --global http.proxy 'http://127.0.0.1:1080'
  git config --global https.proxy 'http://127.0.0.1:1080'
  ```

- 设置socket代理
  
  ```shell
  git config --global http.proxy 'socks5://127.0.0.1:1080'
  git config --global https.proxy 'socks5://127.0.0.1:1080'
  ```

- 取消代理
  
  ```shell
  git config --global --unset http.proxy
  git config --global --unset https.proxy
  ```

## 基本使用

- 拉取代码
  
  ```shell
  git clone https://gitlab.com/username/myrepo.git
  git clone https://${username}:${password}@gitlab.com/username/myrepo.git
  git clone https://gitlab-ci-token:${Personal Access Tokens}@gitlab.com/username/myrepo.git
  ```

* 查看远端分支

  ```shell
  git branch -a
  ```

* 新建分支并切换到指定分支

  ```shell
  git checkout -b dev origin/release/caigou_v1.0
  ```

* 切换本地分支

  ```shell
  git checkout master
  ```

* 将本地分支推送到远程

  ```shell
  git push -u origin dev:release/caigou_v1.0
  ```

# Gitlab维护

## 服务启停

- 载入配置服务（初始化和修改/etc/gitlab/gitlab.rb 后需要重新载入）
  
  ```shell
  sudo gitlab-ctl reconfigure
  ```

- 启动服务
  
  ```shell
  sudo gitlab-ctl start
  ```

- 停止服务
  
  ```shell
  sudo gitlab-ctl stop
  ```

- 重启服务
  
  ```shell
  sudo gitlab-ctl restart
  ```

## 检查服务的日志信息

- 检查redis的日志
  
  ```shell
  sudo gitlab-ctl tail redis
  ```

- 检查postgresql的日志
  
  ```shell
  sudo gitlab-ctl tail postgresql
  ```

- 检查gitlab-workhorse的日志
  
  ```shell
  sudo gitlab-ctl tail gitlab-workhorse
  ```

- 检查logrotate的日志
  
  ```shell
  sudo gitlab-ctl tail logrotate
  ```

- 检查nginx的日志
  
  ```shell
  sudo gitlab-ctl tail nginx
  ```

- 检查sidekiq的日志
  
  ```shell
  sudo gitlab-ctl tail sidekiq
  ```

- 检查unicorn的日志
  
  ```shell
  sudo gitlab-ctl tail unicorn
  ```

- 检查服务状态
  
  ```shell
  sudo gitlab-ctl status
  ```