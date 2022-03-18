# 配置相关

## 安全加固

### open_basedir配置

用于限制各个站点的目录访问权限

#### php-mod模式

```shell
<VirtualHost *:80>
    php_admin_value open_basedir "/var/www/html/web/public:/tmp/"
</VirtualHost>
```
#### php-fpm模式

总限制 通过php-fpm.conf限制增加如下参数

```shell
env[TMP] = /tmp/
env[TMPDIR] = /tmp/
env[TEMP] = /tmp/
php_admin_value[sendmail_path] = /usr/sbin/sendmail -t -i -f webmaster@qq.com
php_admin_value[open_basedir] = /home/wwwroot/:/tmp/:/var/tmp:/proc/
php_admin_value[session.save_path] = /tmp/
php_admin_value[upload_tmp_dir] = /tmp/
slowlog = /usr/local/php/var/log/$pool.log
request_slowlog_timeout = 3s
```

* 方法1 在nginx 配置 fastcgi_param参数

在nginx的 php配置中 或者 在 包含的 include fastcgi.conf 文件中加入：

```shell
fastcgi_param PHP_ADMIN_VALUE "open_basedir=$document_root/:/tmp/:/proc/";
```

$document_root php文档根目录，就是 nginx 配置项 root 配置的网站目录。

/tmp/目录需要有权限，默认放seesion的位置，以及unixsock。

/proc/ 可以让php查看系统负载信息。

本方法加的各个vhost 虚拟主机，都可以完美使用。都限制到自己的网站目录下。

非常推荐使用， 总限制 + 方法1 这样的组合配置方式！！！！！

* 方法2 在php.ini 中配置

在php.ini的末尾加入：

```ini
[HOST=www.iamle.com]
open_basedir=/home/wwwroot/www.iamle.com:/tmp/:/proc/
[PATH=/home/wwwroot/www.iamle.com]
open_basedir=/home/wwwroot/www.iamle.com:/tmp/:/proc/
```

本方法的弊端，如果有泛域名解析，比如 *.iale.com 。这个就不好控制。

* 方法3  网站根目录下增加 .user.ini  文件。

在php.ini中找到user_ini.filename 、 user_ini.cache_ttl 去掉前面的分号。

```ini
; Name for user-defined php.ini (.htaccess) files. Default is ".user.ini"
user_ini.filename = ".user.ini"

; To disable this feature set this option to empty value
;user_ini.filename =

; TTL for user-defined php.ini files (time-to-live) in seconds. Default is 300 seconds (5 minutes)
user_ini.cache_ttl = 300
```

在网站根目录下创建.user.ini 加入：

```ini
open_basedir=/home/wwwroot/www.iamle.com:/tmp/:/proc/
```

这种方式不需要重启nginx或php-fpm服务。

特别注意，需要取消掉.user.ini文件的写权限，这个文件只让最高权限的管理员设置为只读。

方法1设置后，.user.ini的设置就不起作用了。
