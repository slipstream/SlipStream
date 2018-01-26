#!/usr/bin/env bash

#
# To be used on SS server to collect logs, configurations and data.

LOGS=
CONFS=
DATA=
ARCHIVE_TARGZ=/var/tmp/slipstream/ss-arch.tgz
STARTSTOP=
TO_ARCHIVE=

SS_SERVICES="
kibana
filebeat
logstash
graphite-api
carbon-cache
collectd
nginx
elasticsearch
hsqldb
ss-pricing
cimi
slipstream
"

USAGE="usage: -h -l -c -d -f <path> -s\n
\n
-h print this help\n
-l collect logs\n
-c collect configurations\n
-d collect data\n
-s stop/start service before/after achriving\n
-f <path> full path to the tarball. Directories will be created. Default: $ARCHIVE_TARGZ.\n"

_exit_usage() {
    echo -e $USAGE
    exit 1
}

while getopts f:lcdh opt; do
    case $opt in
    l)
        LOGS=true
        ;;
    c)
        CONFS=true
        ;;
    d)
        DATA=true
        ;;
    f)
        ARCHIVE_TARGZ=$OPTARG
        ;;
    s)
        STARTSTOP=true
        ;;
    *|h)
        _exit_usage
        ;;
    esac
done

[ -z "${LOGS}${CONFS}${DATA}" ] && \
    { echo ":: ERROR: No resources to archive were requested."; exit 1; }

mkdir -p `dirname $ARCHIVE_TARGZ`
rm -rf $ARCHIVE_TARGZ

_echo() {
    echo ":: $(date) $@"
}

_is_true() {
    if [ "x${1}" == "xtrue" ]; then
        return 0
    else
        return 1
    fi
}

_stop_services() {
    _is_true $STARTSTOP || return 0
    _echo "Stopping all SlipStream services."
    systemctl stop $SS_SERVICES || true
    _echo "Stopped all SlipStream services."
}

_start_services() {
    _is_true $STARTSTOP || return 0
    _echo "Starting all SlipStream services."
    systemctl start $SS_SERVICES || true
    _echo "Started all SlipStream services."
}

_add() {
   echo ".. Asked to add to archive: $@"
   actual=`ls -d $@ 2>/dev/null || true`
   [ -z "$actual" ] && \
       { echo ".. WARNING: No existing resources to add to archive."; return 0; }

   echo ".. Existing resources to add to archive: $actual"
   for r in $actual; do
       echo "..... adding: $r"
       TO_ARCHIVE="$TO_ARCHIVE $r"
   done
}

_logs() {
    # Installation
    _add /tmp/slipstream*.log

    # SlipStream
    _add /var/log/slipstream

    # SS reports
    _add /var/tmp/slipstream/reports

    # HSQLSB
    _add /var/log/hsqldb.log

    # Elasticsearch
    _add /var/log/elasticsearch

    # Logstash
    _add /var/log/logstash

    # Filebeat
    _add /var/log/filebeat

    # Kibana
    _add /var/log/kibana

    # Collectd
    _add /var/log/collectd.log

    # Graphite
    _add /var/log/graphite-api.log

    # Carbon
    _add /var/log/carbon

    # System
    _add /var/log/messages
}

_configs() {
    # Global
    _add /etc/default

    # SlipStream
    _add /etc/slipstream \
         /opt/slipstream/server/etc \
         /opt/slipstream/server/start.ini

    # HSQLDB (TODO: enable service and sql logs)
    _add /etc/hsqldb.cfg

    # Elasticsearch
    _add /etc/elasticsearch

    # Logstash
    _add /etc/logstash

    # Filebeat
    _add /etc/filebeat

    # Kibana
    _add /etc/kibana

    # Collectd
    _add /etc/collectd.*

    # Graphite
    _add /etc/graphite-api.*

    # Carbon
    _add /etc/carbon
}

_data() {
    # HSQLDB (TODO: enable service and sql logs)
    _add /opt/slipstream/SlipStreamDB

    # Elasticsearch
    _add /var/lib/elasticsearch/nodes

    # Carbon
    _add /var/lib/carbon
}

_create_archive() {
    _echo "Collecting resources to be archived."
    if ( _is_true $LOGS ); then
        _logs
    fi
    if ( _is_true $CONFS ); then
        _configs
    fi
    if ( _is_true $DATA ); then
        _data
    fi
    if [ -z "$TO_ARCHIVE" ]; then
        echo ".. WARNINIG: No resources to archive were collected."
        exit 1
    fi
    _echo "Creating archive: $ARCHIVE_TARGZ"
    tar -zc $TO_ARCHIVE -f $ARCHIVE_TARGZ
    _echo "Created archive: $ARCHIVE_TARGZ"
}

_stop_services
_create_archive
_start_services

