## 常用SQL

* 查找重复ID数据

```sql
SELECT ID 
FROM
	"AFC_ITP_BIZ_COL".inout_records 
WHERE
	ID IN ( SELECT ID FROM "AFC_ITP_BIZ_COL".inout_records GROUP BY ID HAVING COUNT ( ID ) > 1 )
```

