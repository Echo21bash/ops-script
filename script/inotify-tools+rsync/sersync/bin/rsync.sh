#!/bin/bash
#将退出码24视为正常
ignoreexit=24
ignoreout='vanished'
set -o pipefail
rsync "$@" | (grep -v "$ignoreout"|| true)
code=$?
if [ $code == $ignoreexit ]; then
    exit 0
else
    exit $code
fi