FROM postgis/postgis:13-master

ENV TZ Europe/Helsinki

# Install GDAL command line utilities (e.g. ogr2ogr).
RUN set -ex \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    gdal-bin \
 && rm -rf /var/lib/apt/lists/*

ENV PGROUTING_VERSION 3.4.1
ENV PGROUTING_SHA256 a4e034efee8cf67582b67033d9c3ff714a09d8f5425339624879df50aff3f642

# Build and install pgRouting from source.
RUN set -ex \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    libboost-graph1.74.0 \
    libboost-graph1.74-dev \
    libcgal-dev \
    postgresql-server-dev-${PG_MAJOR} \
    wget \
 && wget -O pgrouting.tar.gz "https://github.com/pgRouting/pgrouting/archive/v${PGROUTING_VERSION}.tar.gz" \
 && echo "$PGROUTING_SHA256 *pgrouting.tar.gz" | sha256sum -c - \
 && mkdir -p /usr/src/pgrouting \
 && tar \
  --extract \
  --file pgrouting.tar.gz \
  --directory /usr/src/pgrouting \
  --strip-components 1 \
 && rm pgrouting.tar.gz \
 && cd /usr/src/pgrouting \
 && mkdir build \
 && cd build \
 && cmake .. \
 && make \
 && make install \
 && cd / \
 && rm -rf /usr/src/pgrouting \
 && apt-get purge -y --autoremove \
    build-essential \
    ca-certificates \
    cmake \
    libboost-graph1.74.0 \
    libboost-graph1.74-dev \
    libcgal-dev \
    postgresql-server-dev-${PG_MAJOR} \
    wget \
 && apt-get clean -y \
 && rm -rf /var/lib/apt/lists/*

ENV TIPPECANOE_VERSION 1.36.0
ENV TIPPECANOE_SHA256 0e385d1244a0d836019f64039ea6a34463c3c2f49af35d02c3bf241aec41e71b

# Build and install tippecanoe from source.
RUN set -ex \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
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
    ca-certificates \
    libsqlite3-dev \
    wget \
    zlib1g-dev \
 && apt-get clean -y \
 && rm -rf /var/lib/apt/lists/*

# Set locales.

RUN cp "/usr/share/zoneinfo/${TZ}" /etc/localtime \
 && echo "${TZ}" > /etc/timezone

ADD /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

ADD wait-pg.sh /wait-pg.sh
