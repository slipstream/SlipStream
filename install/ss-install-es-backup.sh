#!/bin/bash
# Install SlipStream ES backup to Amazon S3

# Usage: <AWS ID> <AWS Key>

set -e
set -o pipefail
set -o errtrace


AMAZON_ID=${1:?"Provide Amazon ID"}
AMAZON_KEY=${2:?"Provide Amazon Key"}
S3_BUCKET=slipstream-backup-es
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
    _prints "done."
}

function _create_backup_repo() {
    _printn " creating backup repo... "
    plug=/usr/share/elasticsearch/bin/plugin
    if ( ! $plug list | grep -q cloud-aws ); then
       $plug install cloud-aws
    fi
    curl -XPUT \
        'localhost:9200/_snapshot/es_backup?verify=false&pretty=true' \
        -d'{ "type": "s3", "settings": { "bucket": "'$S3_BUCKET'", "region": "'$S3_REGION'"}}'
    _prints "done."
}

function _configure_es() {
    _printn " configuring Elastic Search backup... "

    ES_CONF=/etc/elasticsearch/elasticsearch.yml
    chgrp elasticsearch $ES_CONF
    chmod 640 $ES_CONF

    AWS_CONF="  aws:
    bucket: $S3_BUCKET
    region: $S3_REGION
    access_key: CHANGE_ME_AWS_ID
    secret_key: CHANGE_ME_AWS_KEY"

    if ( grep -q '^cloud:' $ES_CONF ); then
        if ( grep -q ' aws:' $ES_CONF ); then
            echo "$ES_CONF already constains AWS configuration."
        else
            echo "$AWS_CONF" > aws-conf.txt
            sed -i -e "/cloud:/r aws-conf.txt" $ES_CONF
            rm -f aws-conf.txt
         fi
     else
         cat >> $ES_CONF <<- EOF
cloud:
$AWS_CONF
EOF
    fi

    sed -i -e "s|CHANGE_ME_AWS_ID|${AWS_ID}|" $ES_CONF
    sed -i -e "s|CHANGE_ME_AWS_KEY|${AWS_KEY}|" $ES_CONF

    _prints "done configuring Elastic Search backup."
}

function install_es_backup_S3 () {
    _install
    _create_backup_repo
    _configure_es
}

_print "Installing SlipStream ES backup."
install_es_backup_S3
_print "SlipStream backup ES installed."
