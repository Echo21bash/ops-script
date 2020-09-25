#!/bin/bash

date=`date +%Y%m%d`
echo `date +%Y%m%d-%H%M`：开始备份 >> backup_db.log

echo "------ start backup db ------"

ssh root@10.255.50.144 \ "mkdir -p /data/backup/database/`date +%Y%m%d`"

echo `date +%Y%m%d-%H%M`：创建目录-$date >> backup_db.log

innobackupex --defaults-file=/opt/mysql/my.cnf --no-lock --user 'root' --password '123456' --stream=tar ./ | ssh root@10.255.50.144 \ "cat - > /data/backup/database/`date +%Y%m%d`/`date +%H-%M`-backup.tar"

echo `date +%Y%m%d-%H%M`：备份结束 >> backup_db.log

echo "------ end backup db ------"