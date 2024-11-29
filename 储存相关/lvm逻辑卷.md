# LVM手册

## 基本概念 ##

1、 物理卷-----PV（Physical Volume）
物理卷在逻辑卷管理中处于最底层，它可以是实际物理硬盘上的分区，也可以是整个物理硬盘。

2、 卷组--------VG（Volumne Group）
卷组建立在物理卷之上，一个卷组中至少要包括一个物理卷，在卷组建立之后可动态添加物理卷到卷组中。一个逻辑卷管理系统工

程中可以只有一个卷组，也可以拥有多个卷组。

3、 逻辑卷-----LV（Logical Volume）
逻辑卷建立在卷组之上，卷组中的未分配空间可以用于建立新的逻辑卷，逻辑卷建立后可以动态地扩展和缩小空间。系统中的多个

逻辑卷要以属于同一个卷组，也可以属于不同的多个卷组。

4、 物理区域--PE（Physical Extent）
物理区域是物理卷中可用于分配的最小存储单元，物理区域的大小可根据实际情况在建立物理卷时指定。物理区域大小一旦确定将

不能更改，同一卷组中的所有物理卷的物理区域大小需要一致。

5、 逻辑区域―LE（Logical Extent）
逻辑区域是逻辑卷中可用于分配的最小存储单元，逻辑区域的大小取决于逻辑卷所在卷组中的物理区域的大小。

6、 卷组描述区域-----（Volume Group Descriptor Area）
卷组描述区域存在于每个物理卷中，用于描述物理卷本身、物理卷所属卷组、卷组中的逻辑卷及逻辑卷中物理区域的分配等所有信

息，卷组描述区域是在使用pvcreate建立物理卷时建立的。

## 配置LVM

> 如果单独使用逻辑卷文件系统**使用xfs格式，优点可以扩容inode**

1. 创建物理卷

   ```shell
   pvcreate /dev/mapper/mpatha
   ```
4. 扩展物理卷组

   ```shell
   vgcreate vg1000 /dev/sdb1 /dev/sdb2
   ```

4. 扩展物理卷组

   ```shell
   vgextend centos /dev/mapper/mpatha
   ```

5. 扩展home卷

   ```shell
   lvextend -l +100%FREE /dev/centos/home
   ```

## lvm条带卷

> LVM 逻辑卷有两种读写策略：线性和条带，默认为线性方式
>
> 线性方式（linear）：以一块盘为基础进行读写。当数据写入到一个物理卷（盘）时，写满后才会开始写入下一个物理卷。这种方式的性能较低，因为它无法充分利用多个盘的并行读写能力。
>
> 条带方式（striped）：以多块盘并行读写数据。数据被分成大小相等的条带，然后同时写入到多个物理卷中的相应条带位置。这样可以充分利用多个盘的并行读写能力，从而提高读写性能。

### 创建PV

```shell
[root@itp-mysql-1 ~]# pvcreate /dev/vdb /dev/vdc 
  Physical volume "/dev/vdb" successfully created.
  Physical volume "/dev/vdc" successfully created.
[root@itp-mysql-1 ~]# vgcreate mysqldata /dev/vdb /dev/vdc
  Volume group "mysqldata" successfully created.
```

### 创建条带卷

> -i 条带磁盘数量 -I单次io大小 。类型为striped即可。

```shell
[root@itp-mysql-1 ~]# lvcreate -i 2 -I 64 -l 100%FREE -n mysqldata mysqldata
  Logical volume "mysqldata" created.
[root@itp-mysql-1 ~]# lvdisplay -m  /dev/mysqldata/mysqldata 
  --- Logical volume ---
  LV Path                /dev/mysqldata/mysqldata
  LV Name                mysqldata
  VG Name                mysqldata
  LV UUID                dn20Jb-rdNc-Pnub-Ajnz-n5Up-rxxO-kh77II
  LV Write Access        read/write
  LV Creation host, time itp-mysql-1, 2024-10-15 11:26:48 +0800
  LV Status              available
  # open                 1
  LV Size                <2.93 TiB
  Current LE             767998
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     8192
  Block device           253:2
   
  --- Segments ---
  Logical extents 0 to 767997:
    Type		striped
    Stripes		2
    Stripe size		64.00 KiB
    Stripe 0:
      Physical volume	/dev/vdb
      Physical extents	0 to 383998
    Stripe 1:
      Physical volume	/dev/vdc
      Physical extents	0 to 383998
```

## KVM虚拟机扩容

> 如果原虚拟机磁盘大小加上新扩容空间超过2T，并且原分区表未**使用gpt格式**，数据无备份只能使用添加新盘的方式扩容，并且原分区使用了LVM

### 原盘扩容（新建分区）

1. 关闭虚拟机

   ```shell
   virsh shutdown test
   ```

2. 查看虚拟机磁盘文件分配大小

   ```shell
   qemu-img info /var/lib/libvirt/images/test.qcow2
   ```

3. 在物理机上扩容磁盘文件

   ```shell
   qemu-img resize /var/lib/libvirt/images/test.qcow2 +20G
   ```

4. 再次查看虚拟机磁盘文件分配大小

   ```shell
   qemu-img info /var/lib/libvirt/images/test.qcow2
   ```

5. 启动虚拟机

   ```shell
   virsh start test
   ```

6. 查看磁盘大小

   ```shell
   lsblk
   ```

7. 创建新分区

   ```shell
   fdisk /dev/vda
   输入n 创建分区
   输入p 选择主分区
   输入3 创建分区3
   回车
   继续回车
   输入w 保存
   ```

8. 刷新分区

   ```shell
   partprobe
   ```

9. 查看分区情况

   ```shell
   lsblk
   ```

10. 查看卷组名

    ```shell
    vgdisplay
    ```

11. 创建物理卷

    ```shell
    pvcreate /dev/vda3
    ```

12. 扩展卷组

    ```shell
    vgextend centos /dev/vda3
    ```

    

13. 查看卷组容量

    ```shell
    vgdisplay
    ```

14. 查看当前卷容量

    ```shell
    lvdisplay
    ```

15. 扩展LVM卷

    ```shell
    lvextend -l +100%FREE /dev/centos/home
    ```

16. 再次查看卷容量

    ```shell
    lvdisplay
    ```

17. 查看扩容情况

    ```shell
    lsblk
    ```

18. 查看文件大小

    ```shell
    df -h
    ```

19. 调整文件系统大小

    ```shell
    xfs_growfs /dev/mapper/centos-home
    ```

20. 查看调整情况

    ```shell
    df -h
    ```


### 原盘扩容（原分区）

> **只能是最后一个分区**，`有丢失数据的风险，测试结果是不会丢失数据`

1. 关闭虚拟机

   ```shell
   virsh shutdown test
   ```

2. 查看虚拟机磁盘文件分配大小

   ```shell
   qemu-img info /var/lib/libvirt/images/test.qcow2
   ```

3. 在物理机上扩容磁盘文件

   ```shell
   qemu-img resize /var/lib/libvirt/images/test.qcow2 +20G
   ```

4. 再次查看虚拟机磁盘文件分配大小

   ```shell
   qemu-img info /var/lib/libvirt/images/test.qcow2
   ```

5. 启动虚拟机

   ```shell
   virsh start test
   ```

6. 查看磁盘大小

   ```shell
   lsblk
   ```

7. **查看分区起始值（重要）**

   ```shell
   fdisk -l
   ```

8. 删除分区vda2，然后重新分配分区，**保持分区起始值跟原来一致**

   ```shell
   fdisk /dev/vda
   输入d 删除分区
   输入2 选择分区2
   输入n 创建分区
   输入p 选择主分区
   输入2 创建分区2
   查看默认分区起始值是否为原分区起始分值，如果是直接回车，如果不是输入原起始值
   输入t 选择分区2
   输入8e 设置分区类型为lvm
   继续回车
   输入w 保存
   ```

9. 刷新分区

   ```shell
   partprobe
   ```

10. 查看分区大小

    ```shell
    #分区大小改为新的大小
    lsblk
    ```

11. 查看物理卷大小

    ```shell
    #查看pv大小
    pvdisplay
    pvresize /dev/vda2
    ```

12. 再次查看物理卷大小

    ```shell
    #pv大小应该变成新的容量
    pvdisplay
    ```

13. 扩容逻辑卷

    ```shell
    lvextend -l +100%FREE /dev/centos/home
    ```

14. 查看扩容情况

    ```shell
    lsblk
    ```

15. 调整文件系统大小

    ```shell
    #xfs格式使用
    xfs_growfs /dev/mapper/centos-home
    #ext2/ext3/ext4格式使用
    resize2fs /dev/mapper/centos-home
    ```

16. 查看调整情况

    ```shell
    df -h
    ```


### 添加新盘扩容

1. 关闭虚拟机

   ```shell
   virsh shutdown test
   ```

2. 创建新磁盘

   ```shell
   qemu-img create -f qcow2  /var/lib/libvirt/images/pgsql-extend.qcow2 20G
   ```

3. 修改虚拟机配置文件

   ```shell
   virsh edit test
   ```

4. 启动虚拟机

   ```shell
   virsh start test
   ```

5. lvm添加到原来的卷中，调整文件系统