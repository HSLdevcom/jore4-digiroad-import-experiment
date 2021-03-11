FROM mdillon/postgis:9.6

RUN localedef -i fi_FI -c -f UTF-8 -A /usr/share/locale/locale.alias fi_FI.UTF-8

ADD /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

ENV LANG fi_FI.utf8

ADD wait-pg.sh /wait-pg.sh
