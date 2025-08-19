# Linux问题汇总

## 网络问题

### ethtool

#### 简介

ethtool 是一个 Linux 下的网络驱动程序的诊断和调整工具，可获取网络设备的相关信息，包括连接状态、驱动版本、PCI 总线定位等等

#### 查询网卡基本设置

```shell
[root@app-k8s-node-1 ~]# ethtool ens4f1
Settings for ens4f1:
        Supported ports: [ FIBRE ]
        Supported link modes:   1000baseT/Full
                                10000baseT/Full
        Supported pause frame use: Symmetric Receive-only
        Supports auto-negotiation: No
        Supported FEC modes: Not reported
        Advertised link modes:  10000baseT/Full
        Advertised pause frame use: No
        Advertised auto-negotiation: No
        Advertised FEC modes: Not reported
        Speed: 10000Mb/s
        Duplex: Full
        Auto-negotiation: off
        Port: FIBRE
        PHYAD: 1
        Transceiver: internal
        Supports Wake-on: d
        Wake-on: d
        Current message level: 0x00000000 (0)

        Link detected: yes
```

#### 查询网口驱动相关信息

```shell
[root@app-k8s-node-1 ~]# ethtool -i ens4f1
driver: bnx2x
version: 5.10.0-153.12.0.92.oe2203sp2.x8
firmware-version: mbi 7.15.42 bc 7.15.23
expansion-rom-version:
bus-info: 0000:86:00.1
supports-statistics: yes
supports-test: yes
supports-eeprom-access: yes
supports-register-dump: yes
supports-priv-flags: yes
```

#### 查询网口收发包统计

```shell
[root@app-k8s-node-1 ~]# ethtool -S ens4f1
NIC statistics:
     [0]: rx_bytes: 79656136793
     [0]: rx_ucast_packets: 105342422
     [0]: rx_mcast_packets: 896351
     [0]: rx_bcast_packets: 301258
     [0]: rx_discards: 0
     [0]: rx_phy_ip_err_discards: 0
     [0]: rx_skb_alloc_discard: 0
     [0]: rx_csum_offload_errors: 0
     [0]: tx_exhaustion_events: 0
     [0]: tx_bytes: 2150215884532
```

### 网卡接收错误增长

#### 问题现象

> 如下网卡信息RX errors包数量持续增加，数量几乎等于overruns数量，可以通过ethtool工具排查网卡错误

```shell
ens4f1: flags=6211<UP,BROADCAST,RUNNING,SLAVE,MULTICAST>  mtu 1500
        ether a4:fa:76:00:33:62  txqueuelen 1000  (Ethernet)
        RX packets 43065155382  bytes 23268992350550 (21.1 TiB)
        RX errors 1673119  dropped 11  overruns 1673109  frame 10
        TX packets 40810471807  bytes 18802712989712 (17.1 TiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
        device interrupt 6  memory 0x385ffe000000-385ffe7fffff
# 未发现网卡明显错误统计        
[root@app-k8s-node-1 ~]# ethtool -S ens4f1 | grep -i err
     [0]: rx_phy_ip_err_discards: 0
     [0]: rx_csum_offload_errors: 0
     [1]: rx_phy_ip_err_discards: 0
     [1]: rx_csum_offload_errors: 0
     [2]: rx_phy_ip_err_discards: 0
     [2]: rx_csum_offload_errors: 0
     [3]: rx_phy_ip_err_discards: 0
     [3]: rx_csum_offload_errors: 0
     [4]: rx_phy_ip_err_discards: 0
     [4]: rx_csum_offload_errors: 0
     [5]: rx_phy_ip_err_discards: 0
     [5]: rx_csum_offload_errors: 0
     [6]: rx_phy_ip_err_discards: 0
     [6]: rx_csum_offload_errors: 0
     [7]: rx_phy_ip_err_discards: 0
     [7]: rx_csum_offload_errors: 0
     rx_error_bytes: 0
     rx_crc_errors: 0
     rx_align_errors: 0
     rx_phy_ip_err_discards: 0
     rx_csum_offload_errors: 0
     tx_error_bytes: 0
     tx_mac_errors: 0
     tx_carrier_errors: 0
     tx_deferred: 0
     recoverable_errors: 0
     unrecoverable_errors: 0
# 检查到fifo字段的计数不停增长
[root@app-k8s-node-1 ~]# cat /proc/net/dev | awk '{print$1,$2,$3,$4,$5,$6,$7}' | column -t
Inter-|           Receive         |            Transmit
face              |bytes          packets      errs      drop  fifo     frame
lo:               7505468400      90163030     0         0     0        0
enp61s0f0:        0               0            0         0     0        0
ens4f0:           0               0            0         0     0        0
ens4f1:           23277830485243  43072288786  1673119   11    1673109  10
ens5f0:           0               0            0         0     0        0
ens5f1:           948168744668    1367415008   179       5     179      0

```

#### 问题处理

>当系统内核处理速度跟不上网卡收包速度时，驱动来不及分配缓冲区，NIC 接收到的数据包无法及时写到sk_buffer，就会产生堆积，当 NIC 内部缓冲区写满后，就会丢弃部分数据，引起丢包。这部分丢包为 rx fifo errors，在/proc/net/dev 中体现为 fifo 字段增长，在 ifconfig 中体现为 overruns 指标增长.

```shell
# 查看网卡ring buffer
[root@app-k8s-node-1 ~]# ethtool -g ens4f1
Ring parameters for ens4f1:
Pre-set maximums:
RX:             4078
RX Mini:        n/a
RX Jumbo:       n/a
TX:             4078
Current hardware settings:
RX:             453
RX Mini:        n/a
RX Jumbo:       n/a
TX:             4078
RX Buf Len:             n/a
TX Push:        n/a

# 修改网卡ring buffer
[root@app-k8s-node-1 ~]# ethtool -G ens4f1 rx 4078 tx 4078
[root@app-k8s-node-1 ~]# ethtool -g ens4f1
Ring parameters for ens4f1:
Pre-set maximums:
RX:             4078
RX Mini:        n/a
RX Jumbo:       n/a
TX:             4078
Current hardware settings:
RX:             4078
RX Mini:        n/a
RX Jumbo:       n/a
TX:             4078
RX Buf Len:             n/a
TX Push:        n/a
```

## 进程追踪

### strace

#### 简介

strace 命令是一个集诊断、调试、统计于一体的工具，我们可以使用 strace 跟踪程序的系统调用和信号传递来对程序进行分析，以达到解决问题或者是了解程序工作过程的目的。

#### 使用

> 跟踪正在执行的进程

```shell
[root@node1 ~]# strace -p 736
strace: Process 736 attached
pselect6(8, [3 4], NULL, NULL, NULL, {sigmask=[], sigsetsize=8}
```

> 现在在原来-p的基础上，加上-i参数，可以查看系统调用的入口指针

```shell
[root@node1 ~]# strace -p 736 -i
strace: Process 736 attached
[00007f9726896b1c] pselect6(8, [3 4], NULL, NULL, NULL, {sigmask=[], sigsetsize=8}
```

> 跟踪系统调用的同时，同时打印pid；如果是父进程，则同时跟踪打印子进程的系统调用

```shell
[root@node1 bin]#  strace -p 738  -f
strace: Process 738 attached with 4 threads
[pid  1081] restart_syscall(<... resuming interrupted read ...> <unfinished ...>
[pid   738] restart_syscall(<... resuming interrupted read ...> <unfinished ...>
[pid  1165] restart_syscall(<... resuming interrupted restart_syscall ...> <unfinished ...>
[pid  1091] restart_syscall(<... resuming interrupted restart_syscall ...> <unfinished ...>
[pid  1081] <... restart_syscall resumed>) = -1 ETIMEDOUT (连接超时)
[pid  1081] futex(0x7f1a30021dd0, FUTEX_WAIT_BITSET_PRIVATE, 0, {tv_sec=533163, tv_nsec=6911
```

## 磁盘问题

### IO高排查

> 涉及排查工具iotop、strace

```shell
##使用工具查看磁盘IO、发现jbd2进程占了很大IO
Total DISK READ :       0.00 B/s | Total DISK WRITE :     221.25 K/s
Actual DISK READ:       0.00 B/s | Actual DISK WRITE:      20.93 M/s
    TID  PRIO  USER     DISK READ  DISK WRITE  SWAPIN     IO>    COMMAND
    876 be/3 root        0.00 B/s   8.05 K/s  0.00 %  68.13 % [jbd2/dm-0-8]
2183758 be/4 root        0.00 B/s  3.57 M/s  0.00 %  20.00 % filebeat -c /etc/filebeat/filebeat.yml
3351285 be/4 root        0.00 B/s    3.63 K/s  0.00 %  0.00 % java -Xms128m -Xmx1024m -Djava.s~oneco-apps.jar [sentinel-heartb]
      1 be/4 root        0.00 B/s    0.00 B/s  0.00 %  0.00 % systemd rhgb --switched-root --system --deserialize 18
      2 be/4 root        0.00 B/s    0.00 B/s  0.00 %  0.00 % [kthreadd]
      3 be/0 root        0.00 B/s    0.00 B/s  0.00 %  0.00 % [rcu_gp]
```

> 查阅一些资料后，了解到jbd2进程负责ext4这种日志文件系统的日志提交操作

关于jbd2引起磁盘IO高，网上也有很多类似案例，总结起来有几方面原因：

* 系统bug；

* ext4文件系统的相关配置问题；

* 其他进程的fsync，sync操作过于频繁；

> 首先排除系统bug因素，网络上反馈的问题在很低的版本，我们生产环境为openeuler 2203，其次，查阅了/proc/mounts等信息，发现文件系统配置参数与其他环境差异不大，按照网上提供的关闭某些特性，降低commit 频率等理论来说会有效果，但需要重新mount磁盘，相关组件都要重启，并且这看起来并非根本原因。

```shell
#jbd2进程无法直接使用strace追踪
strace -p 876
strace: attach: ptrace(PTRACE_SEIZE, 876): Operation not permitted

#使用kernel debug开启调试
#jbd2执行flush时输出日志
echo 1 > /sys/kernel/debug/tracing/events/jbd2/jbd2_commit_flushing/enable
#执行sync时输出日志
echo 1 > /sys/kernel/debug/tracing/events/ext4/ext4_sync_file_enter/enable
#然后观察日志输出
cat /sys/kernel/debug/tracing/trace_pipe
     jbd2/dm-0-8-876     [001] .... 1954112.122534: jbd2_commit_flushing: dev 253,0 transaction 1141862986 sync 0
        filebeat-1398234 [023] .... 1954112.123420: ext4_sync_file_enter: dev 253,0 ino 1342182 parent 1342364 datasync 0 
     jbd2/dm-0-8-876     [001] .... 1954112.123776: jbd2_commit_flushing: dev 253,0 transaction 1141862987 sync 0
        filebeat-1398234 [023] .... 1954112.124659: ext4_sync_file_enter: dev 253,0 ino 1342182 parent 1342364 datasync 0 
     jbd2/dm-0-8-876     [001] .... 1954112.125021: jbd2_commit_flushing: dev 253,0 transaction 1141862988 sync 0
        filebeat-1398234 [023] .... 1954112.125956: ext4_sync_file_enter: dev 253,0 ino 1342182 parent 1342364 datasync 0 
     jbd2/dm-0-8-876     [001] .... 1954112.126331: jbd2_commit_flushing: dev 253,0 transaction 1141862989 sync 0
        filebeat-1398234 [023] .... 1954112.128082: ext4_sync_file_enter: dev 253,0 ino 1342182 parent 1342364 datasync 0 
     jbd2/dm-0-8-876     [001] .... 1954112.128455: jbd2_commit_flushing: dev 253,0 transaction 1141862990 sync 0
        filebeat-1398234 [023] .... 1954112.129323: ext4_sync_file_enter: dev 253,0 ino 1342182 parent 1342364 datasync 0 
     jbd2/dm-0-8-876     [001] .... 1954112.129654: jbd2_commit_flushing: dev 253,0 transaction 1141862991 sync 0
        filebeat-1398234 [023] .... 1954112.130515: ext4_sync_file_enter: dev 253,0 ino 1342182 parent 1342364 datasync 0 
     jbd2/dm-0-8-876     [001] .... 1954112.130874: jbd2_commit_flushing: dev 253,0 transaction 1141862992 sync 0
        filebeat-1398234 [023] .... 1954112.131781: ext4_sync_file_enter: dev 253,0 ino 1342182 parent 1342364 datasync 0 
     jbd2/dm-0-8-876     [001] .... 1954112.132134: jbd2_commit_flushing: dev 253,0 transaction 1141862993 sync 0
        filebeat-1398234 [023] .... 1954112.133006: ext4_sync_file_enter: dev 253,0 ino 1342182 parent 1342364 datasync 0 
     jbd2/dm-0-8-876     [001] .... 1954112.133360: jbd2_commit_flushing: dev 253,0 transaction 1141862994 sync 0
        filebeat-1398234 [023] .... 1954112.134236: ext4_sync_file_enter: dev 253,0 ino 1342182 parent 1342364 datasync 0 
     jbd2/dm-0-8-876     [001] .... 1954112.134569: jbd2_commit_flushing: dev 253,0 transaction 1141862995 sync 0
        filebeat-1398234 [023] .... 1954112.135482: ext4_sync_file_enter: dev 253,0 ino 1342182 parent 1342364 datasync 0 
```

> 可以看到jbd2和1342364进程有大量的sync，瞬间刷出大量日志，因此基本确定1342364进程，使用strace工具踪进程的系统调用链

```shell
strace -f -p 1398234
strace: Process 1398234 attached with 37 threads
[pid 1398223] futex(0xc000180148, FUTEX_WAIT_PRIVATE, 0, NULL <unfinished ...>
[pid 1398222] futex(0xc0000ded48, FUTEX_WAIT_PRIVATE, 0, NULL <unfinished ...>
[pid 1398221] futex(0x55906698e500, FUTEX_WAIT_PRIVATE, 0, NULL <unfinished ...>
[pid 1398220] restart_syscall(<... resuming interrupted read ...> <unfinished ...>
[pid 1398121] futex(0x55906695a208, FUTEX_WAIT_PRIVATE, 0, NULL <unfinished ...>
[pid 1398234] epoll_pwait(4,  <unfinished ...>
[pid 1398220] <... restart_syscall resumed>) = -1 EPERM (Operation not permitted)
[pid 1398305] write(11, "d\":\"\",\"source\":\"/host/var/lib/do"..., 4096 <unfinished ...>
[pid 1398234] <... epoll_pwait resumed>[], 128, 0, NULL, 1954221668435469) = 0
[pid 1398220] nanosleep({tv_sec=0, tv_nsec=10000000},  <unfinished ...>
[pid 1398234] epoll_pwait(4,  <unfinished ...>
[pid 1398305] <... write resumed>)      = 4096
[pid 1398305] write(11, "},\n{\"_key\":\"filebeat::logs::nati"..., 4096) = 4096
[pid 1398305] write(11, "e\":\"/host/var/lib/docker/contain"..., 4096 <unfinished ...>
[pid 1398234] <... epoll_pwait resumed>[], 128, 3, NULL, 1954221668435469) = 0
[pid 1398234] futex(0xc0000ded48, FUTEX_WAKE_PRIVATE, 1) = 1
[pid 1398222] <... futex resumed>)      = 0
[pid 1398222] epoll_pwait(4,  <unfinished ...>
[pid 1398234] newfstatat(AT_FDCWD, "/host/var/lib/docker/containers/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421",  <unfinished ...>
[pid 1398222] <... epoll_pwait resumed>[], 128, 0, NULL, 0) = 0
[pid 1398234] <... newfstatat resumed>{st_mode=S_IFDIR|0710, st_size=4096, ...}, 0) = 0
[pid 1398222] epoll_pwait(4,  <unfinished ...>
[pid 1398234] openat(AT_FDCWD, "/host/var/lib/docker/containers/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421", O_RDONLY|O_CLOEXEC) = 18
[pid 1398234] epoll_ctl(4, EPOLL_CTL_ADD, 18, {events=EPOLLIN|EPOLLOUT|EPOLLRDHUP|EPOLLET, data={u32=76928248, u64=139698183197944}}) = -1 EPERM (Operation not permitted)
[pid 1398234] getdents64(18, 0xc000ada000 /* 9 entries */, 8192) = 480
[pid 1398234] getdents64(18, 0xc000ada000 /* 0 entries */, 8192) = 0
[pid 1398234] close(18)                 = 0
[pid 1398234] newfstatat(AT_FDCWD, "/host/var/lib/docker/containers/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421-json.log", {st_mode=S_IFREG|0640, st_size=34147821, ...}, AT_SYMLINK_NOFOLLOW) = 0
[pid 1398234] newfstatat(AT_FDCWD, "/host/var/lib/docker/containers/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421-json.log",  <unfinished ...>
[pid 1398305] <... write resumed>)      = 4096
[pid 1398234] <... newfstatat resumed>{st_mode=S_IFREG|0640, st_size=34147821, ...}, 0) = 0
[pid 1398234] newfstatat(AT_FDCWD, "/host/var/lib/docker/containers/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421-json.log.1",  <unfinished ...>
[pid 1398305] write(11, "\"filebeat::logs::native::1966199"..., 4096 <unfinished ...>
[pid 1398234] <... newfstatat resumed>{st_mode=S_IFREG|0640, st_size=100000123, ...}, AT_SYMLINK_NOFOLLOW) = 0
[pid 1398234] newfstatat(AT_FDCWD, "/host/var/lib/docker/containers/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421-json.log.1", {st_mode=S_IFREG|0640, st_size=100000123, ...}, 0) = 0
[pid 1398234] newfstatat(AT_FDCWD, "/host/var/lib/docker/containers/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421-json.log.2", {st_mode=S_IFREG|0640, st_size=100000027, ...}, AT_SYMLINK_NOFOLLOW) = 0
[pid 1398234] newfstatat(AT_FDCWD, "/host/var/lib/docker/containers/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421-json.log.2", {st_mode=S_IFREG|0640, st_size=100000027, ...}, 0) = 0
[pid 1398234] newfstatat(AT_FDCWD, "/host/var/lib/docker/containers/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421-json.log.2", {st_mode=S_IFREG|0640, st_size=100000027, ...}, 0) = 0
[pid 1398234] newfstatat(AT_FDCWD, "/host/var/lib/docker/containers/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421-json.log.1", {st_mode=S_IFREG|0640, st_size=100000123, ...}, 0) = 0
[pid 1398234] newfstatat(AT_FDCWD, "/host/var/lib/docker/containers/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421/534a67e3b5fc414f0c93c4210eeae6d66af57cc04c96f4a2c38f7c30c6264421-json.log", {st_mode=S_IFREG|0640, st_size=34147821, ...}, 0) = 0
[pid 1398234] futex(0xc000598148, FUTEX_WAIT_PRIVATE, 0, NULL <unfinished ...>
[pid 1398305] <... write resumed>)      = 4096
[pid 1398305] write(11, "containers/cc20812f0d8f5590a7f34"..., 4096) = 4096
[pid 1398305] write(11, "ilebeat::logs::native::1966248-6"..., 4096) = 4096
[pid 1398305] write(11, "333-json.log\",\"timestamp\":[20622"..., 4096) = 4096
[pid 1398305] write(11, "66808-64768\",\"offset\":67552,\"ttl"..., 4096) = 4096
[pid 1398305] write(11, "\":\"/host/var/lib/docker/containe"..., 4096 <unfinished ...>
[pid 1398220] <... nanosleep resumed>NULL) = 0
[pid 1398220] nanosleep({tv_sec=0, tv_nsec=20000}, NULL) = 0
[pid 1398220] futex(0x55906695ebb8, FUTEX_WAIT_PRIVATE, 0, {tv_sec=0, tv_nsec=199918630} <unfinished ...>
[pid 1398305] <... write resumed>)      = 4096
[pid 1398305] futex(0x55906695ebb8, FUTEX_WAKE_PRIVATE, 1) = 1
```

> 发现句柄11在频繁写入,查看句柄对应的目录

```shell
[root@k8s-ywnode10 ~]# ls -lh /proc/1398234/fd/11 
lrwx------ 1 root root 64 Aug 22 13:24 /proc/1398234/fd/11 -> /var/lib/filebeat/registry/filebeat/checkpoint.new
```

> 持续观察该目录发现checkpoint.new频繁创建删除，最后定位到filebeat的异常导致io高。重启filebeat后恢复。正常情况checkpoint.new文件只会创建一次，不会频繁创建删除。具体原因还不清楚发生这种情况的问题。



# TLS  指南

本文档汇总了与 Kubernetes Ingress 环境中 Transport Layer Security (TLS) 相关的关键概念和故障排查步骤，重点涵盖证书管理、服务器名称指示（SNI）、以及使用 Wireshark 等工具进行数据包捕获和解密。文档基于特定场景解决证书不匹配、SNI 处理和解密失败等问题。

## 1. TLS 基础知识

### 1.1 TLS 协议
- **用途**：TLS（传输层安全协议）通过加密数据和验证身份保护客户端与服务器之间的通信。
- **版本**：常用版本包括 TLS 1.2 和 TLS 1.3。TLS 1.2 广泛使用，但由于使用了如 SHA-1 的过时加密算法，安全性低于 TLS 1.3。
- **加密套件**：定义使用的加密算法，例如 `TLS_RSA_WITH_AES_128_CBC_SHA`（RSA 密钥交换，AES-128 加密，SHA-1 哈希）。
  - 示例：`AES128-SHA` 是一个较弱的加密套件，推荐使用现代套件如 `TLS_AES_256_GCM_SHA384`。
- **密钥交换**：常见方法包括 RSA（使用服务器私钥）和 ECDHE（椭圆曲线 Diffie-Hellman 临时密钥，提供前向保密）。

### 1.2 证书和私钥
- **证书**：包含公钥和身份信息（例如 `CN=*.app.com`）。可以是自签名证书或由证书颁发机构（CA）签发。
- **私钥**：用于解密流量或签名数据，必须与证书的公钥匹配。
- **自签名证书**：默认不受信任，常用于内部系统，但会触发验证错误（例如 `self signed certificate`）。

### 1.3 服务器名称指示（SNI）
- **用途**：SNI 允许客户端在 TLS 握手中指定请求的域名（例如 `api.app.com`），使服务器能在单一 IP 上为多个域名选择正确的证书。
- **在 Kubernetes 中的重要性**：NGINX Ingress Controller 依赖 SNI 匹配请求域名与正确的 TLS Secret。

## 2. Kubernetes Ingress 和 TLS

### 2.1 NGINX Ingress Controller
- **作用**：根据 Ingress 资源管理 HTTP/HTTPS 流量路由到后端服务。
- **TLS 配置**：在 Ingress 资源的 `spec.tls` 部分定义，引用包含证书（`tls.crt`）和私钥（`tls.key`）的 Kubernetes Secret。
- **默认证书**：NGINX Ingress Controller 为未匹配或配置错误的请求生成一个自签名的“伪证书”（`Kubernetes Ingress Controller Fake Certificate`）。

### 2.2 Kubernetes Secret 用于 TLS
- **类型**：`kubernetes.io/tls`
- **结构**：
  ```yaml
  apiVersion: v1
  kind: Secret
  metadata:
    name: app.com
    namespace: test
  type: kubernetes.io/tls
  data:
    tls.crt: <base64-encoded-certificate>
    tls.key: <base64-encoded-private-key>
  ```
- **验证**：
  - 提取并解码：
    ```bash
    kubectl get secret app.com -n test -o jsonpath="{.data.tls\.crt}" | base64 -d > tls.crt
    kubectl get secret app.com -n test -o jsonpath="{.data.tls\.key}" | base64 -d > tls.key
    ```
  - 检查证书：
    ```bash
    openssl x509 -in tls.crt -noout -text
    ```
    - 确认 `Subject: CN=*.app.com`。
  - 检查私钥：
    ```bash
    openssl rsa -in tls.key -check
    ```
  - 验证证书和私钥匹配：
    ```bash
    openssl x509 -noout -modulus -in tls.crt | openssl md5
    openssl rsa -noout -modulus -in tls.key | openssl md5
    ```

### 2.3 Ingress 配置
- **示例**：
  
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: api.app.com
    namespace: test
    annotations:
      kubernetes.io/ingress.class: nginx
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
      nginx.ingress.kubernetes.io/client_body_timeout: "180"
      nginx.ingress.kubernetes.io/client_header_timeout: "180"
      nginx.ingress.kubernetes.io/proxy-body-size: "32m"
      nginx.ingress.kubernetes.io/proxy-http-version: "1.1"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
  spec:
    tls:
    - hosts:
      - api.app.com
      secretName: app.com
    rules:
    - host: api.app.com
      http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: client-program-svc
              port:
                number: 7777
  ```
- **关键点**：
  - `spec.tls.hosts` 必须匹配请求的域名（`api.app.com`）。
  - `secretName` 引用 TLS Secret（`app.com`）。
  - `spec.rules.host` 确保域名路由正确。

## 3. TLS 问题排查

### 3.1 证书不匹配
- **症状**：`openssl s_client -connect 172.26.67.9:32443 -servername api.app.com` 显示 `*.app.com` 证书，但 Wireshark 抓包检查`Server Hello`的Protocol: Certificate字段显示`Kubernetes Ingress Controller Fake Certificate`。
- **原因**：
  - **缺少 SNI**：客户端未在 `Client Hello` 中发送 `server_name` 扩展，导致 NGINX 回退到默认证书。
  - **默认证书覆盖**：NGINX Ingress 配置了默认证书（`--default-ssl-certificate`）。

### 3.2 验证 SNI
- **检查 Wireshark 中的 Client Hello**：
  - 过滤器：`tls.handshake.type == 1`
  - 检查 `Extension: server_name` 是否包含 `api.app.com`。
  - 如果缺失，客户端未发送 SNI。

### 3.3 检查 Ingress Controller
- **默认证书**：

  ```bash
  kubectl describe deployment -n <ingress-namespace> -l app.kubernetes.io/name=ingress-nginx
  ##helm配置，配置默认证书为目标证书
  controller:
    config:
      ssl-ciphers: "AES128-SHA:AES256-SHA:AES128-SHA256:AES256-SHA256"
      ssl-protocols: "TLSv1.1 TLSv1.2 TLSv1.3"
      ssl-prefer-server-ciphers: "on"
      use-http2: "false"
    extraArgs:
      default-ssl-certificate: "ingress-nginx/tls-secret"
  ```

## 4. 抓包和解密 TLS 流量

### 4.1 抓包
- **抓取节点端口流量**（`172.26.67.9:32443`）：
  ```bash
  tcpdump -i <interface> host 172.26.67.9 and port 32443 -w new_capture.pcap
  ```

### 4.2 配置 Wireshark 解密

**适用于RSA（使用服务器私钥）密钥交换方式**

> RSA 密钥交换是一种传统的 TLS 密钥交换机制，广泛用于 TLS 1.2 及更早版本（TLS 1.3 已移除 RSA 密钥交换)，RSA 通常与以下 TLS 加密套件结合使用：
>
> TLS_RSA_WITH_AES_128_CBC_SHA（0x002f）：RSA 密钥交换，AES-128-CBC 加密，SHA-1 哈希。
>
> TLS_RSA_WITH_AES_256_CBC_SHA（0x0035）：RSA 密钥交换，AES-256-CBC 加密，SHA-1 哈希。
>
> TLS_RSA_WITH_AES_128_CBC_SHA256（0x003c）：RSA 密钥交换，AES-128-CBC 加密，SHA-256 哈希（更安全）。
>
> TLS_RSA_WITH_AES_256_CBC_SHA256（0x003d）：RSA 密钥交换，AES-256-CBC 加密，SHA-256 哈希。
>
> TLS_RSA_WITH_AES_128_GCM_SHA256（0x009c）：RSA 密钥交换，AES-128-GCM 加密，SHA-256 哈希（更现代）。
>
> TLS_RSA_WITH_AES_256_GCM_SHA384（0x009d）：RSA 密钥交换，AES-256-GCM 加密，SHA-384 哈希。
>
> TLS_RSA_WITH_3DES_EDE_CBC_SHA（0x000a）：RSA 密钥交换，3DES 加密，SHA-1 哈希（已过时，不推荐）。

- **提取私钥**：
  
  ```bash
  kubectl get secret app.com -n test -o jsonpath="{.data.tls\.key}" | base64 -d > tls.key
  ```
  
- **Wireshark 配置**：
  
  - 打开 `Preferences -> Protocols -> TLS -> RSA keys list`。
  - 添加：
    - IP:  `172.26.67.9`
    - Port:  `32443`
    - Protocol: `http`
    - Key File: `tls.key`
  
- **验证解密**：
  
  - 加载 `.pcap` 文件，检查 `http` 过滤器是否显示解密后的 HTTP 流量。
  - 启用 TLS 调试日志（`Preferences -> Protocols -> TLS -> Debug file`）查看错误。

**适用于ECDHE（椭圆曲线 Diffie-Hellman 临时密钥，提供前向保密）**

> ECDHE 通常与以下 TLS 加密套件结合使用：
>
> TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384（0xc030）：ECDHE 密钥交换，RSA 签名，AES-256-GCM 加密。
>
> TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384（0xc02c）：ECDHE 密钥交换，ECDSA 签名，AES-256-GCM 加密。
>
> TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256（0xc02f）：ECDHE 密钥交换，RSA 签名，AES-128-GCM 加密。
>
> TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256（0xcca9）：ECDHE 密钥交换，ECDSA 签名，ChaCha20-Poly1305 加密。
>
> TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA（0xc014）：ECDHE 密钥交换，RSA 签名，AES-256-CBC 加密（较老）

- **配置*SSLKEYLOGFILE***：

  ```bash
  ##客户端或者服务端配置SSLKEYLOGFILE环境变量，配置完成后抓包
  SSLKEYLOGFILE=/var/log/sslkeylog.txt
  ##服务端暂时没有测试
  
  ```

- **Wireshark 配置**：

  > 选择sslkeylog.txt文件

  - 打开 `Preferences -> Protocols -> TLS ->  Pre-Master-Secret log filename`。

* **验证解密**：
  - 加载 `.pcap` 文件，检查 `http` 过滤器是否显示解密后的 HTTP 流量。
  - 启用 TLS 调试日志（`Preferences -> Protocols -> TLS -> Debug file`）查看错误。

### 4.3 解密失败的原因
- **私钥不匹配**：抓包中的证书是 `Kubernetes Ingress Controller Fake Certificate`，而 Wireshark 使用了 `app.com` 的私钥。
- **缺少 SNI**：客户端未发送 `server_name` 扩展，导致返回默认证书。
- **会话重用**：TLS 会话重用（Session ID 或 Ticket）可能导致缺少完整握手数据。

