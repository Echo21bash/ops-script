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
alter tablespace 表空间名 add datafile '+DATADG' size 31G;
```

