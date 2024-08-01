# AWK学习

## AWK函数

### 算数函数

```shell
#rand( )	返回任意数字 n，其中 0 <= n < 1
awk 'BEGIN {
  print "Random num1 =" , rand()
  print "Random num2 =" , rand()
  print "Random num3 =" , rand()
}'

#int( x )	返回 x 的截断至整数的值
awk 'BEGIN {
  param = 5.12345
  result = int(param)

  print "Truncated value =", result
}'
```

### 字符串函数

```shell
#gsub( Ere, Repl, [ In ] ) gsub 是全局替换( global substitution )的缩写。除了正则表达式所有具体值被替代这点，它和 sub 函数完全一样地执行
awk 'BEGIN {
    str = "Hello, World"

    print "String before replacement = " str

    gsub("World", "Jerry", str)

    print "String after replacement = " str
}'

#substr(str, start, l) substr 函数返回 str 字符串中从第 start 个字符开始长度为 l 的子串。如果没有指定 l 的值，返回 str 从第 start 个字符开始的后缀子串

awk 'BEGIN {
    str = "Hello, World !!!"
    subs = substr(str, 1, 5)

    print "Substring = " subs
}'

#length [(String)] 返回 String 参数指定的字符串的长度（字符形式）。如果未给出 String 参数，则返回整个记录的长度（$0 记录变量）,如果指定字符串为数组则返回数组元素个数。
 awk 'BEGIN {
    str = "Hello, World !!!"

    print "Length = ", length(str)
}'

#split( String, A, [Ere] ) 将 String 参数指定的参数分割为数组元素。

awk 'BEGIN {
    str = "One,Two,Three,Four"

    split(str, arr, ",")

    print "Array contains following values"

    for (i in arr) {
        print arr[i]
    }
}'
```

### 其他函数

* 排序函数

`awk`语言中的`asort`函数用于对数组进行排序。它的一般语法如下：

```awk
asort(array [, sorted_array [, how]])
```

- `array` 是要排序的数组名。
- `sorted_array` 是可选参数，用于存储排序后的数组。
- `how` 是可选参数，用于指定排序的方式，可以是`"asc"`（升序，默认）或`"desc"`（降序）。

下面是一个简单的示例，演示如何使用`asort`函数：

```awk
# 创建一个数组
BEGIN {
    fruits[1] = "apple"
    fruits[2] = "orange"
    fruits[3] = "banana"
    fruits[4] = "grape"
    
    # 对数组进行排序
    asort(fruits, sorted_fruits)
    
    # 输出排序后的数组
    for (i = 1; i &lt= length(sorted_fruits); i++) {
        print sorted_fruits[i]
    }
}
```

在这个示例中，`asort(fruits, sorted_fruits)`将数组`fruits`按照默认的升序方式排序，并将排序后的结果存储在`sorted_fruits`数组中。最后，通过循环遍历`sorted_fruits`数组来输出排序后的结果。

记住，`asort`函数会改变传递给它的数组，如果需要保留原始数组，可以在排序之前复制一份。

# AWK示例

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

* 查找file1重复的内容

```shell
awk '{count[$0]++} count[$0]>1 {print $0}' file1
```

## AWK处理csv文件

> 一般来说使用awk处理csv文件是分割符使用-F "," 指定为逗号即可，但是对于csv字段内容包含逗号时，就会出现字段不匹配的问题。使用以下方法可以解决。以下示例为将csv文件第四列排序后输出。

```shell
[root@node1 ~]# cat test.csv
信息,多选题,国家电网公司生产现场作业“十不干”禁令规定，擅自（ ）、（ ），将使作业人员脱离原有安全措施保护范围，极易引发人身触电等安全>事故。," C. 增加或变更工作任务, A. 扩大工作范围, D. 改变工作时间, B. 变更作业人员", C

[root@node1 ~]# awk -vFPAT='([^,]+)|("[^"]+")' 'BEGIN {OFS=","} {
    gsub(/，/, ",", $4);
    gsub(/"| /, "", $4);
    split($4,a,",");
    asort(a);
    sorted_d = "";
    for (i=1;i<=length(a); i++) {
        sorted_d = sorted_d a[i]"；";
    }
    $4 = sorted_d;
    print $0
}' test.csv
信息,多选题,国家电网公司生产现场作业“十不干”禁令规定，擅自（ ）、（ ），将使作业人员脱离原有安全措施保护范围，极易引发人身触电等安全>事故。,A.扩大工作范围；B.变更作业人员；C.增加或变更工作任务；D.改变工作时间；, C
```

