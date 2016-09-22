#!/bin/bash
# Install SlipStream ES backup to Amazon S3

# Usage: <AWS ID> <AWS Key>

set -e
set -o pipefail
set -o errtrace


AMAZON_ID=${1:?"Provide Amazon ID"}
AMAZON_KEY=${2:?"Provide Amazon Key"}

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
    yum install -y slipstream-server-backup-*
    _prints "done."
}

function _create_backup_repo() {
    curl -XPUT 'localhost:9200/_snapshot/es_backup?verify=false&pretty=true' -d'{ "type": "s3", "settings": { "bucket": "slipstream-backup-es", "region": "eu-west"}}'
}

function _configure_es() {
    _printn " configuring Elastic Search backup... "

    ES_CONF=/etc/elasticsearch/elasticsearch.yml
    sed -i -e "s|CHANGE_ME_ID|${AMAZON_ID}|" $ES_CONF
    sed -i -e "s|CHANGE_ME_KEY|${AMAZON_KEY}|" $ES_CONF

    _prints "done configuring Elastic Search backup."
}

function install_es_backup_S3 () {
    _install
    _create_backup_repo
    _configure_es
    systemctl restart crond
}

_print "Installing SlipStream ES backup."
install_es_backup_S3
_print "SlipStream backup ES installed."
