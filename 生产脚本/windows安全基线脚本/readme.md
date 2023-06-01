#### 使用说明

* 需要将security.inf文件放在C:\Windows\System32目录
* 以管理员身份运行build_security_Strategy.bat
* security.inf 文件为windows安全配置内容，可根据具体需求选择配置
#### 参数说明
```inf[]
[Unicode]
Unicode=yes
[Event Audit]
审计登录事件，包括成功和失败
AuditLogonEvents = 3
#审核策略更改，包括成功和失败
AuditPolicyChange = 3
#审核对象访问，包括成功和失败
AuditObjectAccess = 3
#审核特权使用，包括成功和失败
AuditDSAccess = 3
审核过程跟踪，包括失败
AuditPrivilegeUse = 2
审核系统时间，包括成功和失败
AuditSystemEvents = 3
审核账户管理，包括成功和失败
AuditAccountManage = 3
审核目录服务访问，包括成功和失败
AuditProcessTracking = 2
[Registry Values]
不允许SAM账户和共享的匿名连接
MACHINE\System\CurrentControlSet\Control\Lsa\RestrictAnonymous=4,1
不允许SAM账户的匿名枚举
MACHINE\System\CurrentControlSet\Control\Lsa\RestrictAnonymousSAM=4,1
不显示上次登录的用户名
MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System\DontDisplayLastUserName=4,1
当登录时间用完自动注销用户
MACHINE\System\CurrentControlSet\Services\LanManServer\Parameters\EnableForcedLogOff=4,1
清楚虚拟内存页面文件内容
MACHINE\System\CurrentControlSet\Control\Session Manager\Memory Management\ClearPageFileAtShutdown=4,1
关闭磁盘共享
MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters\AutoShareServer=4,0
关闭磁盘共享
MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters\AutoShareWks=4,0
[System Access]
密码最短使用期限
MinimumPasswordAge = 0
密码最长使用期限
MaximumPasswordAge = 60
设置密码长度最小为8位
MinimumPasswordLength = 8
启用密码复杂度，即密码要求数字、字母、特殊字符3种及以上
PasswordComplexity = 1
强制密码历史
PasswordHistorySize = 10
密码锁定阈值为5，即密码试错超过5次就锁定账户
LockoutBadCount = 5
账号锁定时间为30分钟
LockoutDuration = 30
禁用guest账户
EnableGuestAccount = 0
设置默认管理员账号为Administrator，该字段可自定义
NewAdministratorName = "Administrator"
[Privilege Rights]
远程系统强制关机默认为管理员组
SeRemoteShutdownPrivilege = *S-1-5-32-544
取得文件或其他对象所有权配置为管理员组
SeTakeOwnershipPrivilege = *S-1-5-32-544
从网络访问此计算机配置为管理员组，用户组，备份操作员，超级用户
SeNetworkLogonRight = *S-1-5-32-544,*S-1-5-32-545,*S-1-5-32-551,*S-1-5-32-547
[Version]
signature="$CHICAGO$"
Revision=1
```
