@echo off
echo.
echo                 _       .-.                            
echo                :_;      : :                            
echo ,-.,-.,-. .--. .-. .--. : `-. .-..-. .--.  ,-.,-. .--. 
echo : ,. ,. :' '_.': :'  ..': .. :: :; :' .; ; : ,. :' .; :
echo :_;:_;:_;`.__.':_;`.__.':_;:_;`.__.'`.__,_;:_;:_;`._. ;
echo                                                   .-. :    

echo 一键执行，配置windows安全策略
echo 正在配置中......

secedit /configure /db gp.sdb /cfg security.inf

::管理缺失账户
for /f "skip=4 tokens=1-3" %%i in ('net user') do (
	if "%%i"=="Administrator"  echo 请修改默认管理员账号:%%i
	if "%%i"=="Guest"  echo 请禁用用户:%%i
	if "%%j"=="Administrator" echo 请修改默认管理员账号:%%j
	if "%%j"=="Guest"  echo 请禁用用户:%%j
	if "%%k"=="Administrator" echo 请修改默认管理员账号:%%k
	if "%%k"=="Guest"  echo 请禁用用户:%%k
)

::启用SNMP攻击保护
set   EnableDeadGWDetect=False
for /f "skip=2 tokens=1-3" %%i in ('REG QUERY HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters') do if "%%i"=="EnableDeadGWDetect" if "%%k"=="0x0" set EnableDeadGWDetect=True

if %EnableDeadGWDetect%==False (
	REG ADD HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters /f /v EnableDeadGWDetect /t REG_DWORD /d 0 
	echo 启用SNMP攻击保护成功
	rem echo 请添加EnableDeadGWDetect=0x0
)


::启用ICMP攻击保护
set   EnableICMPRedirect=False
for /f "skip=2 tokens=1-3" %%i in ('REG QUERY HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters') do (
	if "%%i"=="EnableICMPRedirect" if "%%k"=="0x0" set EnableICMPRedirect=True
)
if %EnableICMPRedirect%==False (
REG ADD HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters /f /v EnableICMPRedirect /t REG_DWORD /d 0
echo 启用ICMP攻击保护成功
rem echo 请添加EnableICMPRedirect=0x0
) 

::启用SYN攻击保护
set   SynAttackProtect=False
for /f "skip=2 tokens=1-3" %%i in ('REG QUERY HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters') do (
	if "%%i"=="SynAttackProtect" if "%%k"=="0x2" set SynAttackProtect=True
)
if %SynAttackProtect%==False (
REG ADD HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters /f /v SynAttackProtect /t REG_DWORD /d 2
REG ADD HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters /f /v TcpMaxPortsExhausted /t REG_DWORD /d 5
REG ADD HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters /f /v TcpMaxHalfOpen /t REG_DWORD /d 500
REG ADD HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters /f /v TcpMaxHalfOpenRetried /t REG_DWORD /d 400
)

::禁用IP源路由
set   DisableIPSourceRouting=False
for /f "skip=2 tokens=1-3" %%i in ('REG QUERY HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters') do (
	if "%%i"=="DisableIPSourceRouting" if "%%k"=="0x1" set DisableIPSourceRouting=True
)
if %DisableIPSourceRouting%==False (
REG ADD HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters /f /v DisableIPSourceRouting /t REG_DWORD /d 1
echo 禁用IP源路由成功
rem echo 请添加DisableIPSourceRouting=0x1
)

::启用碎片攻击保护
set  EnablePMTUDiscovery=False
for /f "skip=2 tokens=1-3" %%i in ('REG QUERY HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters') do (
	if "%%i"=="EnablePMTUDiscovery" if "%%k"=="0x0" set EnablePMTUDiscovery=True
)
if %EnablePMTUDiscovery%==False (
REG ADD HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters /f /v EnablePMTUDiscovery /t REG_DWORD /d 0
echo 启用碎片攻击保护成功
rem echo 请添加EnablePMTUDiscovery=0x0
)

::远程桌面服务端口管理
set  tcp_PortNumber=False
set  rdp-tcp_PortNumber=False
for /f "skip=2 tokens=1-3" %%i in ('REG QUERY HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal" "Server\Wds\rdpwd\Tds\tcp') do (
	if "%%i"=="PortNumber" if "%%k"=="0xd3d" set tcp_PortNumber=True
)

for /f "skip=2 tokens=1-3" %%i in ('REG QUERY HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal" "Server\WinStations\RDP-Tcp') do (
	if "%%i"=="PortNumber" if "%%k"=="0xd3d" set rdp-tcp_PortNumber=True
)
if %tcp_PortNumber%==True if %rdp-tcp_PortNumber%==True  (
echo 请修改远程桌面端口不为默认端口3389
)

::终端服务登录管理
set  DontDisplayLastUserName=False
for /f "skip=2 tokens=1-3" %%i in ('REG QUERY HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows" "NT\CurrentVersion\Winlogon') do (
	if "%%i"=="DontDisplayLastUserName" if "%%k"=="0x1" set DontDisplayLastUserName=True
)
if %DontDisplayLastUserName% == False (
REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows" "NT\CurrentVersion\Winlogon /f /v DontDisplayLastUserName /t REG_DWORD /d 1
rem echo 请禁止显示上次登录名 DontDisplayLastUserName=0x1
)

::禁止windows自动登录
set AutoAdminLogon=False
for /f  "skip=2 tokens=1,3" %%i in ('REG QUERY HKEY_LOCAL_MACHINE\Software\Microsoft\Windows" "NT\CurrentVersion\Winlogon\ /v AutoAdminLogon') do (
	if "%%j"=="0" set AutoAdminLogon=True
)
if %AutoAdminLogon%==False (
REG ADD HKEY_LOCAL_MACHINE\Software\Microsoft\Windows" "NT\CurrentVersion\Winlogon\ /f /v AutoAdminLogon /t REG_SZ /d 0
echo 禁止windows自动登录成功
rem echo 请添加EnableDeadGWDetect=0
)

::操作系统补丁更新
::net start wuauserv

echo 配置完成
pause







