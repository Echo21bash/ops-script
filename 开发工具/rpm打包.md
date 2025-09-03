# RPM包制作

## 基础环境安装

```shell
###安装rpm开发工具
yum install rpmdevtools
###生成工作目录，默认是在$HOME下rmpbuild
rpmdev-setuptree
```

## 工作目录解释

```shell
BUILD：源码解压以后放的目录

BUILDROOT：虚拟安装目录，即在整个install的过程中临时安装到这个目录，把这个目录当作根来用的，所以在这个目录下的文件，才是真正的目录文件。最终，Spec文件中最后有清理阶段，这个目录中的内容将被删除

RPMS：制作完成后的rpm包存放目录

SOURCES：存放源文件，配置文件，补丁文件等放置的目录【常用】

SPECS：存放spec文件，作为制作rpm包的文件，即：nginx.spec……【常用】

SRPMS：src格式的rpm包目录
```

## spec宏定义

```shell
Name: 软件包的名称，在后面的变量中即可使用%{name}的方式引用

Summary: 软件包的内容

Version: 软件的实际版本号，例如：1.12.1等，后面可使用%{version}引用

Release: 发布序列号，例如：1%{?dist}，标明第几次打包，后面可使用%{release}引用

Group: 软件分组，建议使用：Applications/System

License: 软件授权方式GPLv2

Source: 源码包，可以带多个用Source1、Source2等源，后面也可以用%{source1}、%{source2}引用

BuildRoot: 这个是安装或编译时使用的临时目录，即模拟安装完以后生成的文件目录：%_topdir/BUILDROOT 后面可使用$RPM_BUILD_ROOT 方式引用。

URL: 软件的URI

Vendor: 打包组织或者人员

Patch: 补丁源码，可使用Patch1、Patch2等标识多个补丁，使用%patch0或%{patch0}引用

Prefix: %{_prefix} 这个主要是为了解决今后安装rpm包时，并不一定把软件安装到rpm中打包的目录的情况。这样，必须在这里定义该标识，并在编写%install脚本的时候引用，才能实现rpm安装时重新指定位置的功能

Prefix: %{_sysconfdir} 这个原因和上面的一样，但由于%{_prefix}指/usr，而对于其他的文件，例如/etc下的配置文件，则需要用%{_sysconfdir}标识

Requires: 该rpm包所依赖的软件包名称，可以用>=或<=表示大于或小于某一特定版本，例如：

libxxx-devel >= 1.1.1 openssl-devel 。 注意：“>=”号两边需用空格隔开，而不同软件名称也用空格分开

%description: 软件的详细说明

%define: 预定义的变量，例如定义日志路径: _logpath /var/log/weblog

%prep: 预备参数，通常为 %setup -q

%build: 编译参数 ./configure --user=nginx --group=nginx --prefix=/usr/local/nginx/……

%install: 安装步骤,此时需要指定安装路径，创建编译时自动生成目录，复制配置文件至所对应的目录中（这一步比较重要！）

%pre: 安装前需要做的任务，如：创建用户

%post: 安装后需要做的任务 如：自动启动的任务

%preun: 卸载前需要做的任务 如：停止任务

%postun: 卸载后需要做的任务 如：删除用户，删除/备份业务数据

%clean: 清除上次编译生成的临时文件，就是上文提到的虚拟目录

%files: 设置文件属性，包含编译文件需要生成的目录、文件以及分配所对应的权限

%changelog: 修改历史
```

## rpm制作示例

### kmod-ocfs2制作

> 基于openeuler-oe2203内核5.10.0-60.18.0.50，内核模块单独打包相较普通软件比较复杂，安装后需要执行weak-modules命令，对模块依赖关系更新，否则需要手动执行depmod命令更新modules.dep、modules.dep.bin文件，不然无法加载内核模块。同时weak-modules会在兼容的内核目录/lib/modules/${kernel-version}/weak-updates/创建模块的软连接，做到内核模块和内核分离。

#### 源码准备

```shell
###下载源代码提取ocfs代码
wget https://repo.openeuler.org/openEuler-22.03-LTS/OS/x86_64/Packages/kernel-source-5.10.0-60.18.0.50.oe2203.x86_64.rpm
yum install ./kernel-source-5.10.0-60.18.0.50.oe2203.x86_64.rpm -y
###打包为ocfs2-1.8.0
cp -rp /usr/src/linux-5.10.0-60.18.0.50.oe2203.x86_64/fs/ocfs2/ ocfs2-1.8.0
tar zcf ocfs2-1.8.0.tar.gz ocfs2-1.8.0
```

#### 证书签名

```shell
cat >x509.genkey<<EOF
[ req ]
default_bits = 4096
distinguished_name = req_distinguished_name
prompt = no
x509_extensions = myexts

[ req_distinguished_name ]
O = openEuler
CN = openEuler kernel signing key
emailAddress = kernel@openeuler.org

[ myexts ]
basicConstraints=critical,CA:FALSE
keyUsage=digitalSignature
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid
EOF
openssl req -new -nodes -utf8 -sha256 -days 36500 -batch -x509 -config x509.genkey -outform DER -out signing_key.x509 -keyout signing_key.pem
```

#### spec创建

```shell
# Define the kmod package name here.
%define kmod_name ocfs2
%define dist .oe2203
%define _with_modsign 1
# If kversion isn't defined on the rpmbuild line, define it here.
%{!?kversion: %define kversion 5.10.0-60.18.0.50.oe2203.%{_target_cpu}}

Name:    kmod-%{kmod_name}
Version: 1.8.0
Release: 4%{?dist}
Group:   System Environment/Kernel
License: GPLv2
Summary: %{kmod_name} kernel module(s)
URL:     http://www.kernel.org/

BuildRequires: openEuler-rpm-config,perl
ExclusiveArch: x86_64

# Sources.
Source0:  %{kmod_name}-%{version}.tar.gz
Source1:  signing_key.pem
Source2:  signing_key.x509
Source3:  x509.genkey
# Disable the building of the debug package(s).
%define debug_package %{nil}

%description
This package provides the %{kmod_name} kernel module(s) which allows the mounting of
Macintosh formatted floppy disks and hard disk partitions with full read-write access.
It is built to depend upon the specific ABI provided by a range of releases
of the same variant of the Linux kernel and not on any one specific build.

%prep
%setup -q -n %{kmod_name}-%{version}

%build
KSRC=%{_usrsrc}/kernels/%{kversion}
%{__make} -C "${KSRC}" %{?_smp_mflags} CONFIG_OCFS2_FS=m CONFIG_OCFS2_FS_O2CB=m CONFIG_OCFS2_FS_USERSPACE_CLUSTER=m modules M=$PWD -j 4

%install
%{__install} -d %{buildroot}/lib/modules/%{kversion}/kernel/fs/%{kmod_name}/
%{__install} -pm0644 %{kmod_name}.ko %{kmod_name}_stackglue.ko %{kmod_name}_stack_o2cb.ko %{kmod_name}_stack_user.ko %{buildroot}/lib/modules/%{kversion}/kernel/fs/%{kmod_name}/

%{__install} -d %{buildroot}/lib/modules/%{kversion}/kernel/fs/%{kmod_name}/cluster
%{__install} -pm0644 cluster/%{kmod_name}_nodemanager.ko %{buildroot}/lib/modules/%{kversion}/kernel/fs/%{kmod_name}/cluster

%{__install} -d %{buildroot}/lib/modules/%{kversion}/kernel/fs/%{kmod_name}/dlm
%{__install} -pm0644 dlm/%{kmod_name}_dlm.ko %{buildroot}/lib/modules/%{kversion}/kernel/fs/%{kmod_name}/dlm

%{__install} -d %{buildroot}/lib/modules/%{kversion}/kernel/fs/%{kmod_name}/dlmfs
%{__install} -pm0644 dlmfs/%{kmod_name}_dlmfs.ko %{buildroot}/lib/modules/%{kversion}/kernel/fs/%{kmod_name}/dlmfs


# Strip the modules(s).
find %{buildroot} -type f -name \*.ko -exec %{__strip} --strip-debug \{\} \;

# Sign the modules(s).
%if %{?_with_modsign:1}%{!?_with_modsign:0}
# If the module signing keys are not defined, define them here.

%{!?privkey: %define privkey %{_sourcedir}/signing_key.pem}
%{!?pubkey: %define pubkey %{_sourcedir}/signing_key.x509}
for module in $(find %{buildroot} -type f -name \*.ko);
do /usr/src/kernels/%{kversion}/scripts/sign-file \
    sha256 %{privkey} %{pubkey} $module;
done
%endif

%files
/lib/modules/%{kversion}/kernel/fs/%{kmod_name}/*.ko
/lib/modules/%{kversion}/kernel/fs/%{kmod_name}/cluster/*.ko
/lib/modules/%{kversion}/kernel/fs/%{kmod_name}/dlm/*.ko
/lib/modules/%{kversion}/kernel/fs/%{kmod_name}/dlmfs/*.ko


%clean
%{__rm} -rf %{buildroot}

%post
modules=( $(find /lib/modules/%{kversion}/kernel/fs/%{kmod_name} | grep '\.ko$') )
if [ -x "/sbin/weak-modules" ]; then
    printf '%s\n' "${modules[@]}" | /sbin/weak-modules --add-modules --no-initramfs
fi
%preun
rpm -ql kmod-%{kmod_name}-%{version} | grep '\.ko$' > /var/run/rpm-kmod-%{kmod_name}-modules

%postun
modules=( $(cat /var/run/rpm-kmod-%{kmod_name}-modules) )
rm /var/run/rpm-kmod-%{kmod_name}-modules
if [ -x "/sbin/weak-modules" ]; then
    printf '%s\n' "${modules[@]}" | /sbin/weak-modules --remove-modules --no-initramfs
fi

%changelog
* 2023-06-16 Echo21bash <phil@elrepo.org> - 1.8.0-4
- Rebuilt ocfs2 kernel OE2203

```

#### rpm编译

```shell
#直接编译
rpmbuild -ba SPECS/ocfs2.spec
#传递变量
rpmbuild -ba --define 'dist .oe2203' SPECS/ocfs2.spec
```

