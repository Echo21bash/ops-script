登陆数据库

```shell
sqlplus / as sysdba
```

查看启动模式

```sql
select open_mode from v$database;
```

表空间使用

```sql
select tablespace_name,sum(bytes)/1024/1024 from dba_data_files group by tablespace_name;
```

剩余表空间

```sql
select tablespace_name,sum(bytes)/1024/1024 from dba_free_space group by tablespace_name;
```

增加表空间

```sql
-- 查看数据文件存储方式
-- Oracle的表空间存储方式主要有三种：
-- 文件系统（通常非/dev目录开头，如/oradata
-- 裸设备(通常是/dev/r****方式)
-- ASM（非/开头，以+开头）
select file_id,file_name,tablespace_name from dba_data_files;
```

```sql
-- ASM ASM增加数据文件或者创建表空间不需要指定数据文件名，只要指定 diskgroup即可，ASM会自动命名。
alter tablespace 表空间名 add datafile '+DATADG' size 31G;
-- 文件系统
alter tablespace 表空间名 add datafile '/xx/xx.dbf' size 31G;
-- 裸设备
alter tablespace 表空间名 add datafile '/dev/rlv_name' size 31G;
```

