#!/bin/bash
# Install SlipStream ES backup to S3

set -e
set -o pipefail
set -o errtrace


S3_ID=${1:?"Provide S3 ID"}
S3_KEY=${2:?"Provide S3 Key"}
ES_HOST=${3:?"Provide ES host/IP."}
ES_PORT=${4-9200}
S3_ENDPOINT=${5-s3.amazonaws.com}
S3_BUCKET=${6-slipstream-backup-es}
S3_REGION=eu-west

LOG_FILE=/tmp/slipstream-es-backup-install.log
exec 4>&2 3>&1 1>>${LOG_FILE} 2>&1

SS_USER=slipstream

function _print_on_trap() {
    _prints "\nERROR! Check log file ${LOG_FILE}\n... snippet ...\n$(tail -5 ${LOG_FILE})"
}

function _on_trap() {
    _print_on_trap
}

trap '_on_trap' ERR

function _prints() {
    echo -e "$@" 1>&3
}
function _print() {
    _prints "::: $@"
}
function _printn() {
    echo -en "::: $@" 1>&3
}

function _install() {
    _printn " installing packages... "
    yum install -y slipstream-server-backup
     sed -i \
         -e "s|ES_HOST=.*|ES_HOST=${ES_HOST}|" \
         -e "s|ES_PORT=.*|ES_PORT=${ES_PORT}|" \
         /etc/slipstream/slipstream-es-backup.conf
    _prints "done."
}

function _create_backup_repo() {
    # Assumes repository-s3 plugin is installed on Elasticsearch.
    # We can't do this here as we might be running on another machine.
    # TODO:
    # - "server_side_encryption": true - not included; may not work on Exoscale.
    # - check client-side encryption in ES. See:
    #   https://github.com/elastic/elasticsearch-cloud-aws/pull/118

    _printn " creating backup repo... "
    curl -XPUT \
        "http://${ES_HOST}:${ES_PORT}/_snapshot/es_backup?verify=false&pretty=true" \
        -d'{"type": "s3",
        "settings": {
        "endpoint": "$S3_ENDPOINT",
        "bucket": "'$S3_BUCKET'",
        "region": "eu-west",
        "access_key": "'$S3_ID'",
        "secret_key": "'$S3_KEY'",
        "compress": true,
        "server_side_encryption": true
        }}'
    _prints "done."
}

function install_es_backup_S3 () {
    _install
    _create_backup_repo
}

_print "Installing SlipStream ES backup."
install_es_backup_S3
_print "SlipStream backup ES installed."
