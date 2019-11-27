@echo off
echo ================================================   
echo  windows环境下mysql数据库的自动备份脚本
echo  1. 使用当前日期命名备份文件。
echo  2. 自动删除30天前的备份。
echo ================================================  
::以“yyyymmdd”格式取出当前时间。
set backupdate=%date:~0,4%%date:~5,2%%date:~8,2%
::设置用户名、密码和要备份的数据库。
set user=root
set password=123456
set mysqlip=192.168.10.21
set mysqlhome="d:\mysql\mysql server 5.6"
set datadir=d:\backup\data
set databases=db_librarysys mysql
set logfile=d:\backup\data\log.txt
echo 备份时间:%backupdate%>>%logfile%
::创建备份目录
if not exist "%datadir%" mkdir "%datadir%"
setlocal enabledelayedexpansion
for %%d in (%databases%) do (
   set dbname=%%d

    %mysqlhome%\bin\mysqldump -h%mysqlip% -u%user% -p%password% !dbname! --log-error=%LogFile%>%datadir%\data-!dbname!-%backupdate%.sql
    if !errorlevel! == 0 (
      echo 数据库!dbname!备份成功>>%logfile%
      forfiles /p "%datadir%" /s /m *.* /d -1 /c "cmd /c del @path"
    ) else (
      echo 数据库!dbname!备份失败>>%logfile%
    )
)
echo 备份完成>>%logfile%