#!/bin/bash
set -o pipefail
#将退出码24视为正常
rsync_ignore_exit_code=('24')
rsync_ignore_out='vanished'
rsync "$@" 2>&1 | (grep -Ev "${rsync_ignore_out}"|| true)
exit_code=$?
if [[ ${exit_code} =~ ${rsync_ignore_exit_code} ]]; then
    exit_code=0
fi
exit ${exit_code}