FROM ubuntu:23.04

ADD sersync/ /usr/local/sersync

ADD docker-entrypoint.sh /usr/local/sersync/bin

ENV PATH=$PATH:/usr/local/sersync/bin

RUN sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list && \
    chmod -R +x /usr/local/sersync/bin/* && \
    ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    apt-get update && \
    apt-get install -y rsync inotify-tools openssh-server && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    apt-get clean all

ENTRYPOINT ["docker-entrypoint.sh"]