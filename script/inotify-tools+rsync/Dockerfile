FROM debian:11

ADD sersync/ /usr/local/sersync

ADD docker-entrypoint.sh /usr/local/sersync/bin

ENV PATH=$PATH:/usr/local/sersync/bin

RUN sed -i 's/security-cdn.debian.org/mirrors.aliyun.com' /etc/apt/sources.list && \
    localedef -c -f UTF-8 -i zh_CN zh_CN.UTF-8 && \
    chmod -R +x /usr/local/sersync/bin/* && \
    ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    apt-get install -y rsync inotify-tools && \
    apt-get clean all

ENTRYPOINT ["docker-entrypoint.sh"]
