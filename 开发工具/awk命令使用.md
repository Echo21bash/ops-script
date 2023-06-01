# AWK示例

我的文件共三列文件大致格式如下：

name type value
Chr1 1 4
Chr1 2 14
Chr2 3 45
Chr2 4 45
Chr3 5 456
Chr1 6 23
Chr1 7 14
Chr2 1 32
Chr3 2 3
Chr2 2 3

## AWK统计

* 分组统计

```shell
##单列
awk '{cnt[($3>100?100:$3)]++} END{for(key in cnt) print key ":" cnt[key]}' file
##多列
awk '{a[($2)]++} {b[($3)]++} END{for(key in a) print key ":" a[key]; for(key in b) print key ":" b[key]}' file
##根据条件
awk -F ',' '{if($16=="4" || $16=="3") cnt[($4)]++} END{for(key in cnt) print (key ":" cnt[key])}' trip.csv
```

* 分组求和

```shell
awk '{s[$1] += $2}END{ for(i in s){  print i, s[i] } }' file
```

## AWK文件对比

* 查找file2比file1多的内容

```shell
awk 'NR==FNR{a[$1]=1}NR!=FNR{if(!($1 in a)){print $1}}' file1 file2 
```

