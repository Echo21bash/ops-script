# Postgresql手册

## 基本命令

```sql
---创建账号
CREATE user username PASSWORD 'password';
---修改密码
ALTER USER username WITH PASSWORD 'password';
```

> grant 授权格式: `grant {权限} on {对象} to {账号};`
>
> revoke 回收权限格式: `revoke {权限} on {对象} from {账号};`
>
> pg中有以下权限可分配：
>  `SELECT`,`INSERT`,`UPDATE`,`DELETE`,`TRUNCATE`,`REFERENCES`,`TRIGGER`,`CREATE`,`CONNECT`,`TEMPORARY`,`EXECUTE` 和 `USAGE`

| 权限                | 解释                                                         |
| ------------------- | ------------------------------------------------------------ |
| `CONNECT`           | 允许用户连接数据库                                           |
| `USAGE`             | 1. 模式，允许访问包含在指定模式中的对象（假设该对象的所有权要求同样也设置了）。 最终这些就允许了权限接受者"查询"模式中的对象。 2. 过程语言， 允许使用指定过程语言创建该语言的函数。 这是适用于过程语言的唯一的一种权限类型。 |
| `ALL PRIVILEGES`    | 一次性给予所有可以赋予的权限。 `PRIVILEGES` 关键字在 `PostgreSQL` 里是可选的， 但是严格的 `SQL` 要求有这个关键字。 |
| `CREATE`            | 1. 数据库，允许在该数据库里创建新的模式。 2. 模式，允许在该模式中创建新的对象。 要重命名一个现有对象，你必需拥有该对象并且。 对包含该对象的模式拥有这个权限。 3. 表空间，允许表在该表空间中创建，以及允许创建数据库和模式的时候把该表空间指定为其缺省表空间。        （请注意，撤销这个权限不会改变现有数据库和模式的存放位置。） |
| `TEMPORARY 或 TEMP` | 允许在使用该数据库的时候创建临时表。                         |
| `SELECT`            | 允许对声明的表，视图，或者序列 `SELECT` 任意字段。还允许做  `COPY TO` 的源。 对于序列而言，这个权限还允许使用 `currval` 函数。 |
| `INSERT`            | 允许向声明的表  INSERT 一个新行。 同时还允许做  `COPY FROM`。 |
| `UPDATE`            | 允许对声明的表中任意字段做   `UPDATE`。 `SELECT ... FOR UPDATE` 和 `SELECT ... FOR SHARE` 也要求这个权限（除了 SELECT 权限之外）。比如， 这个权限允许使用`nextval`， 和 `setval`。 |
| `DELETE`            | 允许从声明的表中  `DELETE` 行。                              |
| `RULE`              | 允许在该表/视图上创建规则。                                  |
| `REFERENCES`        | 要创建一个外键约束，你必须在参考表和被参考表上都拥有这个权限。 |
| `TRIGGER`           | 允许在声明表上创建触发器。                                   |
| `EXECUTE`           | 允许使用指定的函数并且可以使用任何利用这些函数实现的操作符。 这是适用于函数的唯一的一种权限类型。 （该语法同样适用于聚集函数。） |

```sql
--- 授权数据库
GRANT { { CREATE | TEMPORARY | TEMP } [,...] | ALL [ PRIVILEGES ] }
    ON DATABASE dbname [, ...]
    TO { username | GROUP groupname | PUBLIC } [, ...] [ WITH GRANT OPTION ]

--- 授权模式
GRANT { { CREATE | USAGE } [,...] | ALL [ PRIVILEGES ] }
    ON SCHEMA schemaname [, ...]
    TO { username | GROUP groupname | PUBLIC } [, ...] [ WITH GRANT OPTION ];

--- 授权表
GRANT { { SELECT | INSERT | UPDATE | DELETE | RULE | REFERENCES | TRIGGER }
    [,...] | ALL [ PRIVILEGES ] }
    ON { [ TABLE ] table_name [, ...]
         | ALL TABLES IN SCHEMA schema_name [, ...] }
    TO { username | GROUP groupname | PUBLIC } [, ...] [ WITH GRANT OPTION ]

--- 授权函数
GRANT { EXECUTE | ALL [ PRIVILEGES ] }
    ON FUNCTION funcname ( [ [ argmode ] [ argname ] argtype [, ...] ] ) [, ...]
    TO { username | GROUP groupname | PUBLIC } [, ...] [ WITH GRANT OPTION ]

--- 授权过程语言
GRANT { USAGE | ALL [ PRIVILEGES ] }
    ON LANGUAGE langname [, ...]
    TO { username | GROUP groupname | PUBLIC } [, ...] [ WITH GRANT OPTION ]

--- 授权表空间
GRANT { CREATE | ALL [ PRIVILEGES ] }
    ON TABLESPACE tablespacename [, ...] 
    TO { username | GROUP groupname | PUBLIC } [, ...] [ WITH GRANT OPTION ]
```

```sql
REVOKE [ GRANT OPTION FOR ]
    { { SELECT | INSERT | UPDATE | DELETE | TRUNCATE | REFERENCES | TRIGGER }
    [, ...] | ALL [ PRIVILEGES ] }
    ON { [ TABLE ] table_name [, ...]
         | ALL TABLES IN SCHEMA schema_name [, ...] }
    FROM { [ GROUP ] role_name | PUBLIC } [, ...]
    [ CASCADE | RESTRICT ]
```

