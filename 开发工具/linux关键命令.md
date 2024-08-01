# Linux常见命令

# strace

## 简介

strace 命令是一个集诊断、调试、统计于一体的工具，我们可以使用 strace 跟踪程序的[系统调用](https://so.csdn.net/so/search?q=系统调用&spm=1001.2101.3001.7020)和信号传递来对程序进行分析，以达到解决问题或者是了解程序工作过程的目的。

## 使用

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

