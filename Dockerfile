FROM misotolar/alpine:3.21.2 AS build

ENV SPINE_VERSION=1.2.28
ARG SHA256=35c25740b4724b02f90f96dcf2dd8a78a9c00ff8b71d3a9b04c0dd0b0d0f0225
ADD https://github.com/Cacti/spine/archive/refs/tags/release/$SPINE_VERSION.tar.gz /tmp/spine.tar.gz

WORKDIR /build

RUN set -ex; \
    apk add --no-cache --virtual .build-deps \
        autoconf \
        automake \
        cmake \
        gcc \
        g++ \
        help2man \
        libtool \
        make \
        mariadb-dev \
        net-snmp-dev \
    ; \
    echo "$SHA256 */tmp/spine.tar.gz" | sha256sum -c -; \
    tar xf /tmp/spine.tar.gz --strip-components=1; \
    ./bootstrap; \
    ./configure; \
    make; \
    chmod u+s /build/spine; \
    scanelf --needed --nobanner /build/spine \
        | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
        | sort -u \
        | xargs -r apk info --installed \
        | sort -u > /build/spineDeps.txt

FROM misotolar/alpine:3.21.2

LABEL maintainer="michal@sotolar.com"

ENV CACTI_VERSION=1.2.28
ARG SHA256=5df738188dbe96711bbb1b09a33b7f31d72f1b1a438afd1e2897ab1a8d99d616
ADD https://github.com/Cacti/cacti/archive/refs/tags/release/$CACTI_VERSION.tar.gz /usr/src/cacti.tar.gz

ENV CACTI_DB_NAME=cacti
ENV CACTI_DB_HOST=localhost
ENV CACTI_DB_USER=cactiuser
ENV CACTI_DB_PASS=cactiuser
ENV CACTI_DB_PORT=3306

ENV CACTI_RDB_NAME=
ENV CACTI_RDB_HOST=localhost
ENV CACTI_RDB_USER=cactiuser
ENV CACTI_RDB_PASS=cactiuser
ENV CACTI_RDB_PORT=3306

ENV CACTI_POLLER_ID=1
ENV CACTI_URL_PATH=/cacti/

ENV PHP_VERSION=83
ENV PHP_MEMORY_LIMIT=400M
ENV PHP_MAX_EXECUTION_TIME=60

COPY --from=build /build/spine /usr/local/bin/spine
COPY --from=build /build/spineDeps.txt /tmp/spineDeps.txt

WORKDIR /usr/local/cacti

RUN set -ex; \
    apk add --no-cache \
        coreutils \
        gettext-envsubst \
        net-snmp-tools \
        perl \
        perl-rrd \
        rrdtool \
        rsync \
        runit \
        tzdata \
        $(cat /tmp/spineDeps.txt) \
    ; \
    apk add --no-cache \
        php$PHP_VERSION \
        php$PHP_VERSION-ctype \
        php$PHP_VERSION-gd \
        php$PHP_VERSION-gettext \
        php$PHP_VERSION-intl \
        php$PHP_VERSION-gmp \
        php$PHP_VERSION-fpm \
        php$PHP_VERSION-ldap \
        php$PHP_VERSION-mbstring \
        php$PHP_VERSION-opcache \
        php$PHP_VERSION-pcntl \
        php$PHP_VERSION-pdo_mysql \
        php$PHP_VERSION-posix \
        php$PHP_VERSION-session \
        php$PHP_VERSION-simplexml \
        php$PHP_VERSION-snmp \
        php$PHP_VERSION-sockets \
        php$PHP_VERSION-xml \
    ; \
    adduser -u 82 -D -S -G www-data www-data; \
    sed -i 's/\[www\]/\[cacti\]/' /etc/php$PHP_VERSION/php-fpm.d/www.conf; \
    echo "$SHA256 */usr/src/cacti.tar.gz" | sha256sum -c -; \
    rm -rf \
        /var/cache/apk/* \
        /var/tmp/* \
        /tmp/*

COPY resources/service /etc/service

COPY resources/php/php-fpm.conf /etc/php$PHP_VERSION/php-fpm.d/yy-cacti-docker.conf
COPY resources/php/php.ini /etc/php$PHP_VERSION/conf.d/98_cacti-docker.ini

COPY resources/spine/local.conf /usr/src/spine.local.conf.docker
COPY resources/spine/remote.conf /usr/src/spine.remote.conf.docker

COPY resources/config.php /usr/src/config.php

COPY resources/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY resources/exclude.txt /usr/src/cacti.exclude

VOLUME /usr/local/cacti/cache
VOLUME /usr/local/cacti/html
VOLUME /usr/local/cacti/log
VOLUME /usr/local/cacti/plugins
VOLUME /usr/local/cacti/resource
VOLUME /usr/local/cacti/rra
VOLUME /usr/local/cacti/scripts

STOPSIGNAL SIGTERM
ENTRYPOINT ["entrypoint.sh"]
CMD ["runsvdir", "-P", "/etc/service"]
