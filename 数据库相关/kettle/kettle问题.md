### Kettle [ETL](https://baike.baidu.com/item/ETL/1251949)工具

下载地址 http://download.thoughtgang.de/pentaho

#### Kettle常见问题

##### 关于kettle的空字符串和NULL的问题

kettle默认情况下把空字符串当作NULL处理

在C:\Users\用户名\.kettle目录中找到kettle.properties文件，增加

KETTLE_EMPTY_STRING_DIFFERS_FROM_NULL=Y