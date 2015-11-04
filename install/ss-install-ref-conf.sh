#!/bin/bash
set -e
set -x
set -o pipefail

_YUM_REPO_KIND_DEFAULT=snapshot
_YUM_REPO_EDITION_DEFAULT=enterprise

declare -A YUM_REPO_TO_GH_BRANCH
YUM_REPO_TO_GH_BRANCH[local]=master
YUM_REPO_TO_GH_BRANCH[${_YUM_REPO_KIND_DEFAULT}]=master
YUM_REPO_TO_GH_BRANCH[candidate]=candidate-latest
YUM_REPO_TO_GH_BRANCH[release]=release-latest

TARBALL_URL=${1:?"Provide reference configuration URL as https://host/path/file.tgz"}
USER_PASS=${2:?"Provide 'user:pass' to get referece configuration."}
YUM_CREDS_URL=${3:?"Provide YUM repo certs URL as https://host/path/file.tgz"}
YUM_CREDS_URL_USERPASS=${4:?"Provide 'user:pass' to get YUM repo certs."}
YUM_REPO_KIND=${5:-${_YUM_REPO_KIND_DEFAULT}}
YUM_REPO_EDITION=${6:-${_YUM_REPO_EDITION_DEFAULT}}

GH_BASE_URL=https://raw.githubusercontent.com/slipstream/SlipStream/${YUM_REPO_TO_GH_BRANCH[${YUM_REPO_KIND}]}

SS_CONF_DIR=/etc/slipstream
mkdir -p $SS_CONF_DIR

function _install_yum_client_cert() {
    # Get and inflate YUM certs.
    TARBALL=~/yum-certs.tgz
    curl -k -L -sSf -u $YUM_CREDS_URL_USERPASS -o $TARBALL $YUM_CREDS_URL
    tar -C $SS_CONF_DIR -zxvf $TARBALL
    chmod 400 $SS_CONF_DIR/yum-client.*
    rm -f $TARBALL
}

function _install_reference_configuration() {
    # Get and inflate the tarball with the server configuration.
    TARBALL=~/ss-ref-conf.tgz
    curl -k -L -sSf -u $USER_PASS -o $TARBALL $TARBALL_URL
    tar -C $SS_CONF_DIR -zxvf $TARBALL
    rm -f $TARBALL

    # Discover connectors that have to be installed.
    CONNECTORS_TO_INSTALL=$(grep -hr cloud.connector.class $SS_CONF_DIR | \
        awk -F= '
    {
        # input: cloud.connector.class = foo:bar, baz
        # ouput: bar baz
        split($2, cnames, ",");
        for (i in cnames) {
            split(cnames[i], cn, ":")
            if (length(cn) == 2) {
                cname = cn[2]
            } else {
                cname = cn[1]
            }
            gsub(/[ \t]/, "", cname)
            print " " cname
        };
    }' | sort -u)

    # Generate new passwords for the defined users.
    for passfile in /etc/slipstream/passwords/*; do
    echo -n $(uuidgen) | tail -c 12 > $passfile
done
}

function _install_slipstream() {
    # Install SlipStream, but don't start it.
    curl -sSf -k -o slipstream.sh $GH_BASE_URL/install/slipstream.sh
    chmod +x slipstream.sh
    ./slipstream.sh -S -k $YUM_REPO_KIND -e $YUM_REPO_EDITION

    # After SS RPM installation our conf file might have been moved. Bring it back.
    if [ -f $SS_CONF_DIR/slipstream.conf.rpmorig ]; then
        mv $SS_CONF_DIR/slipstream.conf.rpmorig $SS_CONF_DIR/slipstream.conf
    fi
}

function _install_slipstream_connectors() {
    # Install required connectors.
    curl -sSf -k -o ss-install-connectors.sh \
        $GH_BASE_URL/install/ss-install-connectors.sh
    chmod +x ss-install-connectors.sh
    ./ss-install-connectors.sh -r $YUM_REPO_KIND $CONNECTORS_TO_INSTALL
}

function _start_slipstream() {
    # Start SlipStream.
    service ssclj start
    service slipstream start
}

_install_yum_client_cert
_install_reference_configuration
_install_slipstream
_install_slipstream_connectors
_start_slipstream
