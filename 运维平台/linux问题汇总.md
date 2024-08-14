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

