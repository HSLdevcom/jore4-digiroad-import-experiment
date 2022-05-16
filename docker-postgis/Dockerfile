FROM pgrouting/pgrouting:13-3.1-3.2.0

ENV TZ Europe/Helsinki
ENV LANG fi_FI.UTF-8
ENV LANGUAGE fi_FI.UTF-8
ENV LC_ALL fi_FI.UTF-8

# Stop apt-get upgrade asking questions.
ENV DEBIAN_FRONTEND=noninteractive

# Upgrade to Debian 11.
RUN set -ex \
 && apt-get update \
 && apt-get upgrade -y \
 && apt-get dist-upgrade -y \
 && apt-get purge -y --autoremove \
 && echo 'deb http://deb.debian.org/debian/ bullseye main contrib non-free\n\
deb-src http://deb.debian.org/debian/ bullseye main contrib non-free\n\
\n\
deb http://security.debian.org/debian-security bullseye-security main contrib non-free\n\
deb-src http://security.debian.org/debian-security bullseye-security main contrib non-free\n\
\n\
deb http://deb.debian.org/debian/ bullseye-updates main\n\
deb-src http://deb.debian.org/debian/ bullseye-updates main'\
 > /etc/apt/sources.list \
 && echo '* libraries/restart-without-asking boolean true' | debconf-set-selections \ 
 && apt-get update \
 && apt-get upgrade -y --without-new-pkgs \
 && apt-get dist-upgrade -y \
 && apt-get purge -y --autoremove \
 && apt-get clean -y \
 && rm -rf /var/lib/apt/lists/*

# "Re-install" PostGIS in order to get shp2pgsql.
RUN set -ex \
 && apt-get update \
 && apt-get install -y \
    postgis \
 && rm -rf /var/lib/apt/lists/*

# Install GDAL command line utilities (e.g. ogr2ogr).
RUN set -ex \
 && apt-get update \
 && apt-get install -y \
    gdal-bin \
 && rm -rf /var/lib/apt/lists/*

ENV TIPPECANOE_VERSION 1.36.0
ENV TIPPECANOE_SHA256 0e385d1244a0d836019f64039ea6a34463c3c2f49af35d02c3bf241aec41e71b

# Build and install tippecanoe from source.
RUN set -ex \
 && apt-get update \
 && apt-get install -y \
    build-essential \
    libsqlite3-dev \
    wget \
    zlib1g-dev \
 && wget -O tippecanoe.tar.gz "https://github.com/mapbox/tippecanoe/archive/refs/tags/${TIPPECANOE_VERSION}.tar.gz" \
 && echo "$TIPPECANOE_SHA256 *tippecanoe.tar.gz" | sha256sum -c - \
 && mkdir -p /usr/src/tippecanoe \
 && tar \
  --extract \
  --file tippecanoe.tar.gz \
  --directory /usr/src/tippecanoe \
  --strip-components 1 \
 && rm tippecanoe.tar.gz \
 && cd /usr/src/tippecanoe \
 && make \
 && make install \
 && cd / \
 && rm -rf /usr/src/tippecanoe \
 && apt-get purge -y --autoremove \
    build-essential \
    libsqlite3-dev \
    wget \
    zlib1g-dev \
 && apt-get clean -y \
 && rm -rf /var/lib/apt/lists/*

# Set locales.

RUN localedef -i fi_FI -c -f UTF-8 -A /usr/share/locale/locale.alias fi_FI.UTF-8

RUN cp "/usr/share/zoneinfo/${TZ}" /etc/localtime \
 && echo "${TZ}" > /etc/timezone

ADD /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

ADD wait-pg.sh /wait-pg.sh
