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

ENV TIPPECANOE_GIT_HASH 18e53cd7fb9ae6be8b89d817d69d3ce06f30eb9d

# Build and install tippecanoe from source.
RUN set -ex \
 && apt-get update \
 && apt-get install -y \
    build-essential \
    git \
    libsqlite3-dev \
    zlib1g-dev \
 && mkdir -p /usr/src/tippecanoe \
 && git clone https://github.com/mapbox/tippecanoe.git /usr/src/tippecanoe \
 && cd /usr/src/tippecanoe \
 && git checkout ${TIPPECANOE_GIT_HASH} \
 && make \
 && make install \
 && cd / \
 && rm -rf /usr/src/tippecanoe \
 && apt-get purge -y --autoremove \
    build-essential \
    git \
    libsqlite3-dev \
    zlib1g-dev \
 && apt-get clean -y \
 && rm -rf /var/lib/apt/lists/*

# Set locales.

RUN localedef -i fi_FI -c -f UTF-8 -A /usr/share/locale/locale.alias fi_FI.UTF-8

RUN cp "/usr/share/zoneinfo/${TZ}" /etc/localtime \
 && echo "${TZ}" > /etc/timezone

ADD /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

ADD wait-pg.sh /wait-pg.sh
