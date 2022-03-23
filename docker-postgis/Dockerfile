FROM pgrouting/pgrouting:13-3.1-3.2.0

ENV TZ Europe/Helsinki
ENV LANG fi_FI.UTF-8
ENV LANGUAGE fi_FI.UTF-8
ENV LC_ALL fi_FI.UTF-8

RUN `#1. Update current packages.` \
 && set -ex \
 && apt-get update \
 && apt-get -y upgrade \
 && apt-get -y dist-upgrade \
 && apt-get -y --purge autoremove \
 && `#2. Modify the repositories.` \
 && echo 'deb http://deb.debian.org/debian/ bullseye main contrib non-free\n\
deb-src http://deb.debian.org/debian/ bullseye main contrib non-free\n\
\n\
deb http://security.debian.org/debian-security bullseye-security main contrib non-free\n\
deb-src http://security.debian.org/debian-security bullseye-security main contrib non-free\n\
\n\
deb http://deb.debian.org/debian/ bullseye-updates main\n\
deb-src http://deb.debian.org/debian/ bullseye-updates main'\
 > /etc/apt/sources.list \
 && `#3. Upgrade to Debian 11.` \
 && echo '* libraries/restart-without-asking boolean true' | debconf-set-selections \ 
 && apt-get update \
 && apt-get -y --without-new-pkgs upgrade \
 && apt-get -y dist-upgrade \
 && `#4. Install required packages for shp2pgsql, ogr2ogr and tippecanoe.` \
 && apt-get -y install \
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
 && `#5. Clean and remove unneeded build dependencies.` \
 && apt-get -y --purge remove build-essential git \
 && apt-get -y --purge autoremove \
 && apt-get -y clean

# Set locales.

RUN localedef -i fi_FI -c -f UTF-8 -A /usr/share/locale/locale.alias fi_FI.UTF-8

RUN cp "/usr/share/zoneinfo/${TZ}" /etc/localtime \
 && echo "${TZ}" > /etc/timezone

ADD /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

ADD wait-pg.sh /wait-pg.sh
