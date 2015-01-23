#!/bin/bash
# Install SlipStream backup to Amazon S3

# Usage: <S3 bucket URL> <AWS ID> <AWS Key> <Instance ID> [cron: *false*/true]

set -ex

# https://s3-eu-west-1.amazonaws.com/<bucket name>
AMAZON_BUCKET=${1:?"Provide full URL to S3 bucket."} # $(ss-get aws-bucket)
AMAZON_ID=${2:?"Provide Amazon ID"}
set +x
AMAZON_KEY=${3:?"Provide Amazon Key"}
set -x
INSTANCE_ID=${4:?"Provide instance ID (e.g., IP/hostname)."}
BACKUP_VIA_CRON={$5:-"false"} # false or true

function install_backup_S3 () {

    yum install -y slipstream-server-backup

	S3CURL_CONF=/opt/slipstream/server/.s3curl
    cp -f /opt/slipstream/backup/s3curl.cfg.tpl $S3CURL_CONF
    chmod 600 $S3CURL_CONF
    chown slipstream: $S3CURL_CONF
    sed -i -e "s|CHANGE_ME_ID|${AMAZON_ID}|" $S3CURL_CONF
    set +x
    sed -i -e "s|CHANGE_ME_KEY|${AMAZON_KEY}|" $S3CURL_CONF
    set -x

    sed -i -e "s|AMAZON_BUCKET=.*|AMAZON_BUCKET=${AMAZON_BUCKET}|" \
        -e "s|SS_HOSTNAME=.*|SS_HOSTNAME=${INSTANCE_ID}|" \
        /etc/slipstream/slipstream-backup.conf

    # Enable backup via cron (e.g., if Nagios monitoring is not enabled).
    [ "$BACKUP_VIA_CRON" == "true" ] && \
    	{ sed -i 's/^#//' /etc/cron.d/slipstream-backup; service crond start; }
}

install_backup_S3
