FROM ubuntu:23.10

ADD sersync/ /usr/local/sersync

ADD docker-entrypoint.sh /usr/local/sersync/bin

ENV PATH=$PATH:/usr/local/sersync/bin LC_ALL=zh_CN.UTF-8

RUN sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.lis && \
    apt-get update && \
    apt-get install -y locales tzdata rsync inotify-tools openssh-server language-pack-zh-hans && \
    chmod -R +x /usr/local/sersync/bin/* && \
    ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    locale-gen zh_CN.UTF-8 && \
    apt-get clean all

WORKDIR /usr/local/sersync/

ENTRYPOINT ["docker-entrypoint.sh"]