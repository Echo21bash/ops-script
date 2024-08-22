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

strace 命令是一个集诊断、调试、统计于一体的工具，我们可以使用 strace 跟踪程序的[系统调用](https://so.csdn.net/so/search?q=系统调用&spm=1001.2101.3001.7020)和信号传递来对程序进行分析，以达到解决问题或者是了解程序工作过程的目的。

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
