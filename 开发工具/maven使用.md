# Maven使用手册

## 基础环境安装

> 配置java环境，下载maven安装包即可

## 打包命令

### 基础打包命令

```shell
#编译,将Java 源程序编译成 class 字节码文件
mvn compile
#测试，并生成测试报告
mvn test
#将以前编译得到的旧的 class 字节码文件删除
mvn clean
#动态web工程打war包,Java工程打jar包.
mvn pakage
#将项目生成 jar 包放在仓库中，以便别的模块调用
mvn install 
#打成jar包，并且抛弃测试用例打包
mvn clean install -Dmaven.test.skip=true 
#动态 web工程打 war包，Java工程打 jar 包 ，并且抛弃测试用例打包
mvn clean pakage -Dmaven.test.skip=true
```

### 多模块打包

>多模块打包也可使用基础打包命令进行打包，但是实际使用中，假如使用微服务架构，更新其中的一个子服务时，没有必要对整个工程打包。可使用该方法进行单独打包子服务。

```shell
Maven选项：
-pl, --projects
    Build specified reactor projects instead of all projects
-am, --also-make
    If project list is specified, also build projects required by the list
-amd, --also-make-dependents
    If project list is specified, also build projects that depend on projects on the list
```

```shell
#首先切换到工程的根目录
mvn install -pl jsoft-web -am
mvn install -pl jsoft-common -am -amd
```



