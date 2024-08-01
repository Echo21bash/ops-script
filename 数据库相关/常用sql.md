## 常用SQL

* 查找重复ID数据

```sql
SELECT ID 
FROM
	"AFC_ITP_BIZ_COL".inout_records 
WHERE
	ID IN ( SELECT ID FROM "AFC_ITP_BIZ_COL".inout_records GROUP BY ID HAVING COUNT ( ID ) > 1 )
	
	
SELECT id FROM "AFC_ITP_BUSINESS".mobile_pay_refundorders GROUP BY ID HAVING COUNT ( id ) > 1 
```

