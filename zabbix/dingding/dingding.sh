#!/bin/bash
#钉钉告警

to=$1
subject=$2
text=$3
curl 'https://oapi.dingtalk.com/robot/send?access_token=5ff7091b00ff7e147eb36c7be5d52261311b60ad07780f97c9b511c30ee05629' \
-H 'Content-Type: application/json' \
-d '''
{
    "msgtype": "text",
    "text": {
        "content":  "'"@138xxxxxxxx$text"'" #这里写确里人绑定钉钉的手机号+$text,粘贴后删除此注释
    },
    "at": {
        "atMobiles": [
            "138xxxxxxxx",   #群里人绑定钉钉的手机号，粘贴后删除此注释
            ""
        ],
        "isAtAll": false
    }
}'''
