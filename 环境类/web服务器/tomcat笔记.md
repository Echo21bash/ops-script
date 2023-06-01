# Tomcat相关

## 设置为系统服务

### Windows

Windows下解压版Tomcat添加系统服务的方法

* 方法一
  1. 打开cmd命令窗口
  2. 进入Tomcat-bin路径
  3. 运行service install
  4. 即可安装系统服务默认的服务名为omcat8
* 方法二 自定义服务名
  1. 将修改startup.bat文件中的tomcat8.exe替换tomcat-test.exe
  2. 将bin目录中的tomcat8.exe重命名为tomcat-test.exe
  3. 将bin目录中的tomcat8w.exe重命名为tomcat-testw.exe
  4. 运行service.bat install test这样就把服务名称改为了test
