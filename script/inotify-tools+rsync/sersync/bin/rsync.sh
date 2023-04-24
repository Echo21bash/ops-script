#!/bin/bash
#将退出码24视为正常
(rsync "$@"; if [ $? == 24 ]; then exit 0; else exit $?; fi) | grep -v 'vanished'
