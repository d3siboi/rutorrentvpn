# syntax=docker/dockerfile:1
#
# STEP 2 of the hotio+rtorrent build: compile-only.
# This builds libtorrent + rtorrent + mktorrent (and their deps) from source.
# There is deliberately no runtime/VPN layer yet and no ruTorrent yet — that's
# Step 3 and Step 4. The only goal here is: does everything compile cleanly?
#
# Versions pinned to match crazymax's tested combination (docker-rtorrent-rutorrent),
# confirmed to build against the same Alpine 3.23 base that hotio/base:alpinevpn uses.

ARG ALPINE_VERSION=3.24

ARG CARES_VERSION=1.34.8
ARG CURL_VERSION=8.21.0
ARG LIBTORRENT_VERSION=v0.16.27 # renovate: datasource=github-releases depName=rakshasa/libtorrent
ARG RTORRENT_VERSION=v0.16.27 # renovate: datasource=github-releases depName=rakshasa/rtorrent
ARG MKTORRENT_VERSION=v1.1
ARG DUMPTORRENT_VERSION=v1.7.0 # renovate: datasource=github-releases depName=tomcdj71/dumptorrent
ARG RAR_VERSION=723 # RARLAB isn't on GitHub — no Renovate datasource for this one, bump by hand against https://www.rarlab.com/download.htm
ARG RUTORRENT_VERSION=v5.3.20 # renovate: datasource=github-releases depName=Novik/ruTorrent
ARG FILEMANAGER_VERSION=v1.6.0 # renovate: datasource=github-releases depName=nelu/rutorrent-filemanager

# ---------------------------------------------------------------------------
# Source-fetch stages — one per component, so Docker's layer cache only
# re-downloads a component if its ARG version actually changes.
# ---------------------------------------------------------------------------

FROM alpine:${ALPINE_VERSION} AS src
RUN apk --update --no-cache add curl git tar tree sed xz
WORKDIR /src

FROM src AS src-cares
ARG CARES_VERSION
RUN curl -sSL "https://github.com/c-ares/c-ares/releases/download/v${CARES_VERSION}/c-ares-${CARES_VERSION}.tar.gz" | tar xz --strip 1

FROM src AS src-curl
ARG CURL_VERSION
RUN curl -sSL "https://curl.se/download/curl-${CURL_VERSION}.tar.gz" | tar xz --strip 1

FROM src AS src-libtorrent
RUN git init . && git remote add origin "https://github.com/rakshasa/libtorrent.git"
ARG LIBTORRENT_VERSION
RUN git fetch origin "${LIBTORRENT_VERSION}" && git checkout -q FETCH_HEAD

FROM src AS src-rtorrent
RUN git init . && git remote add origin "https://github.com/rakshasa/rtorrent.git"
ARG RTORRENT_VERSION
RUN git fetch origin "${RTORRENT_VERSION}" && git checkout -q FETCH_HEAD

FROM src AS src-mktorrent
RUN git init . && git remote add origin "https://github.com/pobrn/mktorrent.git"
ARG MKTORRENT_VERSION
RUN git fetch origin "${MKTORRENT_VERSION}" && git checkout -q FETCH_HEAD

FROM src AS src-dumptorrent
RUN git init . && git remote add origin "https://github.com/tomcdj71/dumptorrent.git"
ARG DUMPTORRENT_VERSION
RUN git fetch origin "${DUMPTORRENT_VERSION}" && git checkout -q FETCH_HEAD

FROM src AS src-rutorrent
RUN git init . && git remote add origin "https://github.com/Novik/ruTorrent.git"
ARG RUTORRENT_VERSION
RUN git fetch origin "${RUTORRENT_VERSION}" && git checkout -q FETCH_HEAD

FROM src AS src-filemanager
RUN git init . && git remote add origin "https://github.com/nelu/rutorrent-filemanager.git"
ARG FILEMANAGER_VERSION
RUN git fetch origin "${FILEMANAGER_VERSION}" && git checkout -q FETCH_HEAD

# GeoLite2 requires a MaxMind account for direct downloads now — this is the
# same periodically-updated mirror crazymax's own build pulls from, on his
# own GitHub account (same maintainer as docker-rtorrent-rutorrent itself).
# Deliberately not pinned: this is data, not code, and a fresh copy on every
# rebuild is what you actually want.
FROM src AS src-mmdb
RUN curl -SsOL "https://github.com/crazy-max/geoip-updater/raw/mmdb/GeoLite2-City.mmdb" \
  && curl -SsOL "https://github.com/crazy-max/geoip-updater/raw/mmdb/GeoLite2-Country.mmdb"

# geoip2-rutorrent isn't independently versioned upstream — it's a subfolder
# of crazymax's own repo, not a separately-tagged project, so there's no
# release for Renovate to track. Deliberately unpinned instead, same
# philosophy as hotio/base and the mmdb data above: always fetch current,
# let the weekly scheduled rebuild be what actually catches upstream
# changes, rather than force this into the Renovate-PR pattern it doesn't
# cleanly fit.
FROM src AS src-geoip2-crazymax
RUN git init . && git remote add origin "https://github.com/crazy-max/docker-rtorrent-rutorrent.git"
RUN git fetch origin master && git checkout -q FETCH_HEAD

# composer:2 resolves geoip2-rutorrent's PHP dependency (the official
# MaxMind geoip2/geoip2 package) the same way crazymax's own build does.
FROM composer:2 AS vendor-geoip2-rutorrent
WORKDIR /app
COPY --from=src-geoip2-crazymax /src/geoip2-rutorrent/composer.json /src/geoip2-rutorrent/composer.lock ./
RUN composer install --no-dev --no-interaction --no-progress --optimize-autoloader

FROM src AS src-geoip2-rutorrent
COPY --from=src-geoip2-crazymax /src/geoip2-rutorrent /src
COPY --from=vendor-geoip2-rutorrent /app/vendor /src/vendor

# ---------------------------------------------------------------------------
# Builder stage — plain alpine:3.23, NOT crazymax/alpine-s6.
# We don't need his s6-overlay layer to compile anything, and skipping it
# means one less external image to pull. gosu is also dropped: hotio/base
# already handles the UID/GID drop with its own s6-setuidgid, which is what
# our service scripts will use in Step 4.
#
# php84-dev/php84-pear/gd-dev are intentionally omitted here — nothing in
# this stage touches PHP or GD. They come back when we build ruTorrent's
# layer in Step 4.
# ---------------------------------------------------------------------------

FROM alpine:${ALPINE_VERSION} AS builder
RUN apk --update --no-cache add \
    autoconf \
    automake \
    binutils \
    brotli-dev \
    build-base \
    cmake \
    cppunit-dev \
    libpsl-dev \
    libsigc++3-dev \
    libtool \
    libxslt-dev \
    linux-headers \
    ncurses-dev \
    nghttp2-dev \
    openssl-dev \
    pcre-dev \
    tar \
    tree \
    xz \
    zlib-dev \
    zstd-dev

ENV DIST_PATH="/dist"

# --- c-ares (async DNS resolver; libcurl and libtorrent both link against it) ---
WORKDIR /usr/local/src/cares
COPY --from=src-cares /src .
RUN cmake . -D CARES_SHARED=ON -D CMAKE_BUILD_TYPE:STRING="Release" -D CMAKE_C_FLAGS_RELEASE:STRING="-O3 -flto=\"$(nproc)\" -pipe"
RUN cmake --build . --clean-first --parallel $(nproc)
RUN make install -j$(nproc)
RUN make DESTDIR=${DIST_PATH} install -j$(nproc)
RUN tree ${DIST_PATH}

# --- curl (built against the c-ares we just installed system-wide above) ---
WORKDIR /usr/local/src/curl
COPY --from=src-curl /src .
RUN cmake . -D ENABLE_ARES=ON -D CURL_LTO=ON -D CURL_USE_OPENSSL=ON -D CURL_BROTLI=ON -D CURL_ZSTD=ON -D BUILD_SHARED_LIBS=ON -D CMAKE_BUILD_TYPE:STRING="Release" -D CMAKE_C_FLAGS_RELEASE:STRING="-O3 -flto=\"$(nproc)\" -pipe"
RUN cmake --build . --clean-first --parallel $(nproc)
RUN make install -j$(nproc)
RUN make DESTDIR=${DIST_PATH} install -j$(nproc)
RUN tree ${DIST_PATH}

# --- libtorrent (must be installed system-wide before rtorrent's ./configure runs) ---
WORKDIR /usr/local/src/libtorrent
COPY --from=src-libtorrent /src .
RUN autoreconf -vfi
RUN ./configure --enable-aligned
RUN make -j$(nproc) CXXFLAGS="-w -O3 -flto -Werror=odr -Werror=lto-type-mismatch -Werror=strict-aliasing"
RUN make install -j$(nproc)
RUN make DESTDIR=${DIST_PATH} install -j$(nproc)
RUN tree ${DIST_PATH}

# --- rtorrent (vanilla rakshasa build, tinyxml2 xmlrpc backend is vendored — no extra dep needed) ---
WORKDIR /usr/local/src/rtorrent
COPY --from=src-rtorrent /src .
RUN autoreconf -vfi
RUN ./configure --with-xmlrpc-tinyxml2 --with-ncurses
RUN make -j$(nproc) CXXFLAGS="-w -O3 -flto -Werror=odr -Werror=lto-type-mismatch -Werror=strict-aliasing"
RUN make install -j$(nproc)
RUN make DESTDIR=${DIST_PATH} install -j$(nproc)
RUN tree ${DIST_PATH}

# --- mktorrent (standalone, no dependency on the above) ---
WORKDIR /usr/local/src/mktorrent
COPY --from=src-mktorrent /src .
RUN echo "CC = gcc" >> Makefile
RUN echo "CFLAGS = -w -flto -O3" >> Makefile
RUN echo "USE_PTHREADS = 1" >> Makefile
RUN echo "USE_OPENSSL = 1" >> Makefile
RUN make -j$(nproc)
RUN make install -j$(nproc)
RUN make DESTDIR=${DIST_PATH} install -j$(nproc)
RUN tree ${DIST_PATH}

# --- dumptorrent (also builds scrapec, a tracker-scrape companion tool) ---
WORKDIR /usr/local/src/dumptorrent
COPY --from=src-dumptorrent /src .
RUN cmake -B build/ -DCMAKE_CXX_COMPILER=g++ -DCMAKE_C_COMPILER=gcc -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-include sys/time.h" -S .
RUN cmake --build build/ --config Release --parallel $(nproc)
RUN cp build/dumptorrent build/scrapec ${DIST_PATH}/usr/local/bin
RUN tree ${DIST_PATH}

# ---------------------------------------------------------------------------
# Runtime stage — this is Step 3: hotio/base:alpinevpn plus our compiled
# binaries and a new "service-rtorrent" that hotio's s6-rc supervises the
# same way it supervises its own services. Everything else (WireGuard,
# nftables, Privoxy, Unbound, the forwarder) is untouched, inherited as-is.
#
# Cross-checked against hotio/base's packages.txt: it already ships
# libstdc++, libncursesw/libpanelw, libssl3/libcrypto3, zstd-libs, libpsl,
# and nghttp2-libs — everything our compiled curl/libtorrent/rtorrent need
# except libsigc++3 (libtorrent's signal/slot dependency), which is the
# only package we add here.
# ---------------------------------------------------------------------------

FROM ghcr.io/hotio/base:alpinevpn AS runtime

# libsigc++3: from Step 3, libtorrent's signal/slot dependency.
# Everything else below is new in Step 4 — nginx, PHP-FPM, and the specific
# PHP extensions ruTorrent actually touches (bcmath for large torrent-size
# math, curl/dom/simplexml/xml for RSS and RPC parsing, fileinfo for upload
# mime detection, session for auth, zip for the create/extract features).
# apache2-utils gives us htpasswd for basic auth in 4c.
RUN apk --update --no-cache add \
    apache2-utils \
    ffmpeg \
    libsigc++3 \
    mediainfo \
    nginx \
    nginx-mod-http-dav-ext \
    php84 \
    php84-bcmath \
    php84-ctype \
    php84-curl \
    php84-dom \
    php84-fileinfo \
    php84-fpm \
    php84-mbstring \
    php84-openssl \
    php84-posix \
    php84-session \
    php84-simplexml \
    php84-sockets \
    php84-xml \
    php84-zip \
    py3-pip \
    sox \
    zip \
  && pip3 install --upgrade --break-system-packages pip \
  && pip3 install --break-system-packages cfscrape cloudscraper

# RARLAB's rar (archive creation) — proprietary shareware, not open source.
# RARLAB's own policy tolerates personal/home use indefinitely (the "trial"
# nag never actually expires); a paid license is required for commercial
# use. Only creation is added here — hotio/base already builds unrar
# (extraction) from RARLAB's separately-licensed free unrar source, so
# there's no need to duplicate that binary. RARLAB doesn't publish an
# unversioned "latest" URL (an earlier attempt assumed one existed based on
# an unofficial README — it didn't, hence the 404); every real download on
# their own page is version-pinned, confirmed directly against
# https://www.rarlab.com/download.htm.
ARG RAR_VERSION
RUN curl -sSL "https://www.rarlab.com/rar/rarlinux-x64-${RAR_VERSION}.tar.gz" | tar xz -C /tmp \
  && install -Dm755 /tmp/rar/rar /usr/local/bin/rar \
  && rm -rf /tmp/rar

COPY --from=builder /dist /
COPY --from=src-rutorrent --chown=hotio:hotio /src /var/www/rutorrent
COPY --from=src-filemanager --chown=hotio:hotio /src /var/www/rutorrent/plugins/filemanager
COPY --from=src-geoip2-rutorrent --chown=hotio:hotio /src /var/www/rutorrent/plugins/geoip2
COPY --from=src-mmdb --chown=hotio:hotio /src/GeoLite2-City.mmdb /var/www/rutorrent/plugins/geoip2/database/GeoLite2-City.mmdb
COPY --from=src-mmdb --chown=hotio:hotio /src/GeoLite2-Country.mmdb /var/www/rutorrent/plugins/geoip2/database/GeoLite2-Country.mmdb
RUN rm -rf /var/www/rutorrent/plugins/geoip
COPY root/ /

RUN find /etc/s6-overlay/s6-rc.d -type f \( -name "run" -o -name "finish" -o -name "up" \) -exec chmod +x {} +
