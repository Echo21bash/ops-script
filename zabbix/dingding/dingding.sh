#!/bin/bash
#钉钉告警
to=$1
subject=$2
text=$3
sendkey=5ff7091b00ff7e147eb36c7be5d52261311b60ad07780f97c9b511c30ee05629
curl 'https://oapi.dingtalk.com/robot/send?access_token='$sendkey \
-H 'Content-Type: application/json' \
-d '''
{
    "msgtype": "text",
    "text": {
        "content":  "'"$text"'"
    },
    "at": {
        "atMobiles": ['$to'],
        "isAtAll": false
    }
}'''

