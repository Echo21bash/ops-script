#!/bin/bash
set -o pipefail
TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT
currentDate=$(date +%Y-%m-%d)
logsFile=${logs_dir:-${TMPDIR}}/${currentDate}_${remote_sync_dir:-non}_${rsyncd_ipaddr:-non}.rsync.log
#将退出码24视为正常
rsync_ignore_exit_code=('24')
rsync "$@" 2>&1 | xargs -I{} echo {} >> ${logsFile}
exit_code=$?
if [[ ${exit_code} =~ ${rsync_ignore_exit_code} ]];then
    exit_code=0
fi
exit ${exit_code}