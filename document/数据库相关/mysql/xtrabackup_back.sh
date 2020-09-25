#!/bin/bash
mysql_user='root'
mysql_passwd='123456'
mysql_config_file='/opt/mysql/my.cnf'
remote_host='10.255.50.144'

date=`date +%Y%m%d`
echo `date +%Y%m%d-%H%M`：开始备份 >> backup_db.log

echo "------ start backup db ------"

ssh ${remote_host} \ "mkdir -p /data/backup/database/`date +%Y%m%d`"

echo `date +%Y%m%d-%H%M`：创建目录-$date >> backup_db.log

innobackupex --defaults-file=${mysql_config_file} --no-lock --user=${mysql_user} --password=${mysql_passwd} --stream=tar ./ | gzip | ssh ${remote_host} \ "cat - > /data/backup/database/`date +%Y%m%d`/`date +%H-%M`-backup.tar"

echo `date +%Y%m%d-%H%M`：备份结束 >> backup_db.log

echo "------ end backup db ------"