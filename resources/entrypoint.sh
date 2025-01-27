#!/bin/sh

set -ex

. entrypoint-common.sh

entrypoint-hooks.sh

if [ ! -d /usr/src/cacti ]; then
    mkdir -p /usr/src/cacti
    tar -xf /usr/src/cacti.tar.gz -C /usr/src/cacti --strip-components=1
fi

rsync -rlD --delete --exclude-from=/usr/src/cacti.exclude /usr/src/cacti/ /usr/local/cacti/html

cp /usr/src/config.php /usr/local/cacti/html/include/config.php

if [ ! -f /usr/local/cacti/etc/csrf-secret.php ]; then
    touch /usr/local/cacti/etc/csrf-secret.php
    chown www-data:www-data /usr/local/cacti/etc/csrf-secret.php
fi

for data in cache log plugins resource rra scripts; do
    mkdir -p /usr/local/cacti/${data}
    chown -R www-data:www-data /usr/local/cacti/${data}
    ln -sft /usr/local/cacti/html /usr/local/cacti/${data}
done

for cache in boost mibcache realtime spikekill; do
    mkdir -p /usr/local/cacti/cache/${cache}
    chown -R www-data:www-data /usr/local/cacti/cache/${cache}
done

for resource in resource/script_queries resource/script_server resource/snmp_queries; do
    mkdir -p /usr/local/cacti/${resource}
    chown -R www-data:www-data /usr/local/cacti/${resource}
done

if [ -z "${CACTI_RDB_NAME}" ]; then
    envsubst < "/usr/src/spine.remote.conf.docker" > "/etc/spine.conf"
else
    envsubst < "/usr/src/spine.local.conf.docker" > "/etc/spine.conf"
fi

entrypoint-post-hooks.sh

exec "$@"
