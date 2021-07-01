FROM postgis/postgis:13-master

# Update system and install required packages for ogr2ogr and tippecanoe.
RUN set -ex \
 && apt-get update \
 && apt-get -y upgrade \
 && apt install -y gdal-bin build-essential git libsqlite3-dev zlib1g-dev

# Create a directory and copy in tippecanoe source files.
RUN mkdir -p /tmp/tippecanoe-src
RUN git clone https://github.com/mapbox/tippecanoe.git /tmp/tippecanoe-src

WORKDIR /tmp/tippecanoe-src

# Build tippecanoe.
RUN make \
  && make install

# Remove the temp directory and unneeded packages used to build tippecanoe.
WORKDIR /
RUN rm -rf /tmp/tippecanoe-src \
  && apt-get -y remove --purge build-essential git \
  && apt-get -y autoremove

# Set locales.

RUN localedef -i fi_FI -c -f UTF-8 -A /usr/share/locale/locale.alias fi_FI.UTF-8

RUN cp /usr/share/zoneinfo/Europe/Helsinki /etc/localtime
RUN echo "Europe/Helsinki" > /etc/timezone

ADD /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

ENV TZ Europe/Helsinki
ENV LANG fi_FI.UTF-8
ENV LANGUAGE fi_FI.UTF-8
ENV LC_ALL fi_FI.UTF-8

ADD wait-pg.sh /wait-pg.sh
