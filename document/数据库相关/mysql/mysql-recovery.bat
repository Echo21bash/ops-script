@echo off
echo ================================================   
echo  Windows环境下Mysql数据库的自动恢复脚本
echo  1. 使用当前日期命名备份文件。
echo  2. 自动删除7天前的备份。
echo ================================================  
::以“YYYYMMDD”格式取出当前时间。
set BACKUPDATE=%date:~0,4%%date:~5,2%%date:~8,2%
::设置用户名、密码和要恢复的数据库。
set USER=root
set PASSWORD=123456
set DATABASE=mysql
set MYSQLIP=192.168.30.47
::创建恢复目录
if not exist "D:\backup\data"       mkdir D:\backup\data
set DATADIR=D:\backup\data
mysql -h%MYSQLIP% -u%USER% -p%PASSWORD% %DATABASE% < %DATADIR%\data-%BACKUPDATE%.sql

pause