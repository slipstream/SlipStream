#!/bin/bash
# Install SlipStream backup to Amazon S3

# Usage: <S3 bucket URL> <AWS ID> <AWS Key> <Instance ID>

set -e
set -o pipefail
set -o errtrace

# https://s3-eu-west-1.amazonaws.com/<bucket name>
AMAZON_BUCKET=${1:?"Provide full URL to S3 bucket."} # $(ss-get aws-bucket)
AMAZON_ID=${2:?"Provide Amazon ID"}
AMAZON_KEY=${3:?"Provide Amazon Key"}
INSTANCE_ID=${4:?"Provide instance ID (e.g., IP/hostname)."}

LOG_FILE=/tmp/slipstream-backup-install.log
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

function _configure() {
    _printn " configuring... "
    S3CURL_CONF=/opt/slipstream/server/.s3curl
    cp -f /opt/slipstream/backup/s3curl.cfg.tpl $S3CURL_CONF
    chmod 600 $S3CURL_CONF
    chown $SS_USER: $S3CURL_CONF
    sed -i -e "s|CHANGE_ME_ID|${AMAZON_ID}|" $S3CURL_CONF
    sed -i -e "s|CHANGE_ME_KEY|${AMAZON_KEY}|" $S3CURL_CONF

    sed -i -e "s|AMAZON_BUCKET=.*|AMAZON_BUCKET=${AMAZON_BUCKET}|" \
        -e "s|SS_HOSTNAME=.*|SS_HOSTNAME=${INSTANCE_ID}|" \
        /etc/slipstream/slipstream-backup.conf \
        /etc/slipstream/slipstream-es-backup.conf
    mkdir -p /var/log/slipstream/
    chown slipstream. /var/log/slipstream/
    _prints "done."
}

function install_backup_S3 () {
    _install
    _configure
    systemctl restart crond
}

_print "Installing SlipStream backup."
install_backup_S3
_print "SlipStream backup installed."
