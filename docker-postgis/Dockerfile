FROM pgrouting/pgrouting:13-3.1-3.2.0

ENV TZ Europe/Helsinki
ENV LANG fi_FI.UTF-8
ENV LANGUAGE fi_FI.UTF-8
ENV LC_ALL fi_FI.UTF-8

# Update system and install required packages for shp2pgsql, ogr2ogr and tippecanoe.
RUN set -ex \
 && apt-get update \
 && apt-get -y upgrade \
 && apt install -y \
    postgis \
    gdal-bin \
    build-essential \
    git \
    libsqlite3-dev \
    zlib1g-dev \
 && mkdir -p /tmp/tippecanoe-src \
 && git clone https://github.com/mapbox/tippecanoe.git /tmp/tippecanoe-src \
 && cd /tmp/tippecanoe-src \
 && make \
 && make install \
 && cd / \
 && rm -rf /tmp/tippecanoe-src \
 && apt-get -y remove --purge build-essential git \
 && apt-get -y autoremove

# Set locales.

RUN localedef -i fi_FI -c -f UTF-8 -A /usr/share/locale/locale.alias fi_FI.UTF-8

RUN cp "/usr/share/zoneinfo/${TZ}" /etc/localtime \
 && echo "${TZ}" > /etc/timezone

ADD /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

ADD wait-pg.sh /wait-pg.sh
