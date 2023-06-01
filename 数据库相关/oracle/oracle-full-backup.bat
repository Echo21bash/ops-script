@echo off
echo ================================================   
echo  Windows环境下Oracle数据库的自动备份脚本
echo  1. 使用当前日期命名备份文件。
echo  2. 自动删除7天前的备份。
echo ================================================  
::以“YYYYMMDD”格式取出当前时间。
set BACKUPDATE=%date:~0,4%%date:~5,2%%date:~8,2%
::设置用户名、密码和要备份的数据库。
set USER=system
set PASSWORD=123456
set DATABASE=ORCL
::创建备份目录
if not exist "D:\backup\data"       mkdir D:\backup\data
if not exist "D:\backup\log"        mkdir D:\backup\log
set DATADIR=D:\backup\data
set LOGDIR=D:\backup\log
exp %USER%/%PASSWORD%@192.168.30.40:1521/%DATABASE% full=y file=%DATADIR%\data_%BACKUPDATE%.dmp log=%LOGDIR%\log_%BACKUPDATE%.log
::删除7天前的备份。  
forfiles /p "%DATADIR%" /s /m *.* /d -7 /c "cmd /c del @path"
forfiles /p "%LOGDIR%" /s /m *.* /d -7 /c "cmd /c del @path"