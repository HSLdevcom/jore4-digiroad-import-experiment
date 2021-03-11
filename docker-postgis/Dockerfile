FROM postgis/postgis:13-master

RUN localedef -i fi_FI -c -f UTF-8 -A /usr/share/locale/locale.alias fi_FI.UTF-8

RUN cp /usr/share/zoneinfo/Europe/Helsinki /etc/localtime
RUN echo "Europe/Helsinki" > /etc/timezone

ADD /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

ENV TZ Europe/Helsinki
ENV LANG fi_FI.UTF-8
ENV LANGUAGE fi_FI.UTF-8
ENV LC_ALL fi_FI.UTF-8

ADD wait-pg.sh /wait-pg.sh
