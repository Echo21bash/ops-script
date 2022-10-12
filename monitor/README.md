# 纯脚本实现告警

## 简单介绍

>本脚本用于对http、tcp端口进行简单监控并对异常情况通过企业微信、钉钉进行告警。针对与没有完成的监控平台又有监控告警的场景使用。

## 使用说明

### 目录结构说明

>bin目录存放监听脚本、conf目录存放配置文件、logs存放日志。
>
>* get-status.sh脚本用于获取监控指标，目前支持http、tcp检测；
>* monitor.sh脚本是启动脚本，周期性调用get-status.sh脚本获取监控指标，并对需要告警的监控项通过调用wechat-robot.sh脚本发送告警通知；
>* wechat-robot.sh脚本用于向企业微信群发送消息通知；
>* dingtalk-robot.sh脚本用于向钉钉群发送消息通知；
>* stop.sh脚本用于停止服务监控；
>* monitor.conf主配置文件

### 配置监控

> 编辑配置文件monitor.conf根据实际情况进行配置

```shell
####################告警渠道配置####################
#告警渠道[wechat,dingtalk]可多选
alarm_channel=("wechat" "dingtalk")
#企业微信机器人token
wechat_token="9c348e49-cd68-4628-9375-b964118cd986"
#钉钉机器人token
dingtalk_token="f6a8b8e0ceaa748ff58ee08ba5e21579f7bb1b7d420072df9a34d8d5c3be3b1f"
#####################监控项配置#####################
#监控指标周期(s)
interval_time="30"
##监控项配置(关联数组)##
#声明关联数组名称
declare -A monitor_list
#配置监控项格式monitor_list[服务名]='监听地址'
#服务名必须唯一，支持汉字、字母、数据
#监听地址格式HTTP[http://www.baidu.com]
#监听地址格式TCP[tcp:www.baidu.com:443]
monitor_list[baidu]='http://www.baidu.com'
monitor_list[tencent]='https://www.qq.com'
```

### 启动脚本

```shell
sh ./bin/monitor.sh &
```

### 停止脚本

```shell
sh ./bin/stop.sh
```

