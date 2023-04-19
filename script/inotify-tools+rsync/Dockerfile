FROM centos:7

ADD sersync/ /usr/local/sersync

ADD docker-entrypoint.sh /usr/local/sersync/bin

ADD CentOS7-Base.repo /etc/yum.repos.d/CentOS-Base.repo

ADD CentOS7-epel.repo /etc/yum.repos.d/CentOS-epel.repo

ENV PATH=$PATH:/usr/local/sersync/bin

RUN localedef -c -f UTF-8 -i zh_CN zh_CN.UTF-8 && \
    chmod -R +x /usr/local/sersync/bin/* && \
    ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    yum install -y rsync inotify-tools && \
    yum clean all

ENTRYPOINT ["docker-entrypoint.sh"]
