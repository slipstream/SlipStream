#!/bin/bash
set -e
set -x
set -o pipefail

TARBALL_URL=${1:?"Provide reference configuration URL as https://host/path/file.tgz"}
USER_PASS=${2:?"Privde 'user:pass' to get referece configuration."}
YUM_CREDS_URL=${3:?"Provide YUM repo certs URL as https://host/path/file.tgz"}
YUM_CREDS_URL_USERPASS=${4:?"Provide 'user:pass' to get YUM repo certs."}
YUM_REPO=${5:-Snapshots-enterprise}
GIT_BRANCH=${6:-master}

GH_BASE_URL=https://raw.githubusercontent.com/slipstream/SlipStream/$GIT_BRANCH

SS_CONF_DIR=/etc/slipstream
mkdir -p $SS_CONF_DIR

# Get and inflate YUM certs.
TARBALL=~/yum-certs.tgz
curl -k -L -sSf -u $YUM_CREDS_URL_USERPASS -o $TARBALL $YUM_CREDS_URL
tar -C $SS_CONF_DIR -zxvf $TARBALL
chmod 400 $SS_CONF_DIR/yum-client.*
rm -f $TARBALL

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

# Install SlipStream, but don't start it.
curl -sSf -k -o slipstream.sh $GH_BASE_URL/install/slipstream.sh
chmod +x slipstream.sh
./slipstream.sh -S -s $YUM_REPO

# After SS RPM installation our conf file might have been moved. Bring it back.
if [ -f $SS_CONF_DIR/slipstream.conf.rpmorig ]; then
    mv $SS_CONF_DIR/slipstream.conf.rpmorig $SS_CONF_DIR/slipstream.conf
fi

# Install required connectors.
curl -sSf -k -o ss-install-connectors.sh \
    $GH_BASE_URL/install/ss-install-connectors.sh
chmod +x ss-install-connectors.sh
./ss-install-connectors.sh $CONNECTORS_TO_INSTALL

# Start SlipStream.
service ssclj start
service slipstream start

