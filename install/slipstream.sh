#!/usr/bin/env bash
#
# SlipStream 2.3 PROD installation recipe
#

# THIS SCRIPT CONTAINS A HACK see at the bottom

# Fail fast and fail hard.
set -eo pipefail

function abort() {
    echo $1
    exit 1
}

### Parameters

# First "global" IPv4 address
SS_HOSTNAME=$(ip addr | awk '/inet .*global/ { split($2, x, "/"); print x[1] }' | head -1)
[ -z "$SS_HOSTNAME" ] && \
    abort "Could not determinee IP or hostname of the public interface SlipStream will running on."
echo SS_HOSTNAME=$SS_HOSTNAME

# Type of repository to lookup for SlipStream packages. 'Releases' will install
# stable releases, whereas 'Snapshots' will install unstable/testing packages.
SS_REPO_KIND=Releases
echo SS_REPO_KIND=$SS_REPO_KIND

# libcloud
CLOUD_CLIENT_LIBCLOUD_VERSION=0.14.1

# EPEL repository
EPEL_VER=6-8

# Packages from PyPi for SlipStream Client
PYPI_PARAMIKO_VER=1.9.0
PYPI_SCPCLIENT_VER=0.4

### Advanced parameters
CONFIGURE_FIREWALL=true

SLIPSTREAM_SERVER_HOME=/opt/slipstream/server

SLIPSTREAM_CONF=/etc/slipstream/slipstream.conf

DEPS="unzip curl wget gnupg nc python-pip"
CLEAN_PKG_CACHE="yum clean all"

###############################################

alias cp='cp'

function isTrue() {
    if [ "x${1}" == "xtrue" ]; then
        return 0
    else
        return 1
    fi
}

function configure_firewall () {
    isTrue $CONFIGURE_FIREWALL || return 0

    cat > /etc/sysconfig/iptables <<EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF
    service iptables restart
}

function _add_yum_repos () {
    # EPEL
    EPEL_PKG=epel-release-${EPEL_VER}.noarch
    rpm -Uvh --force http://mirror.switch.ch/ftp/mirror/epel/6/i386/${EPEL_PKG}.rpm

    # Nginx
	rpm -Uvh --force http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm

    # SlipStream
	rpm -Uvh --force http://yum.sixsq.com/slipstream/centos/6/slipstream-repos-1.0-1.noarch.rpm
	yum-config-manager --disable SlipStream-*
	yum-config-manager --enable SlipStream-${SS_REPO_KIND}
}

function disable_selinux() {
    echo 0 > /selinux/enforce
    sed -i -e 's/^SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux /etc/selinux/config
}

function prepare_node () {

	yum install -y yum-utils

    _add_yum_repos

    echo "Installing $DEPS ..."
    yum install -y --enablerepo=epel $DEPS

    configure_firewall

    # Schema based http proxy for Python urllib2
    cat > /etc/default/jetty <<EOF
export JETTY_HOME=$SLIPSTREAM_SERVER_HOME
export TMPDIR=$SLIPSTREAM_SERVER_HOME/tmp
EOF
    cat >> /etc/default/jetty <<EOF
export http_proxy=$http_proxy
export https_proxy=$https_proxy
export JETTY_HOME=$SLIPSTREAM_SERVER_HOME
EOF

   disable_selinux
}

function deploy_HSQLDB () {
    echo "Installing HSQLDB..."

    service hsqldb stop || true
    kill -9 $(cat /var/run/hsqldb.pid) || true
    rm -f /var/run/hsqldb.pid

    yum install -y slipstream-hsqldb

    echo "Starting HSQLDB..."
    service hsqldb start || true # false-positive failure
}

function deploy_SlipStreamServerDependencies () {
    deploy_HSQLDB
}

function deploy_SlipStreamClient () {

    # Required by SlipStream cloud clients CLI
    pip install -Iv apache-libcloud==${CLOUD_CLIENT_LIBCLOUD_VERSION}

    # Required by SlipStream ssh utils
    yum install -y gcc python-devel
    # python-crypto clashes with Crypto installed as dependency with paramiko
    yum remove -y python-crypto
    pip install -Iv paramiko==$PYPI_PARAMIKO_VER
    pip install -Iv scpclient==$PYPI_SCPCLIENT_VER

    # winrm
    pip install https://github.com/diyan/pywinrm/archive/a2e7ecf95cf44535e33b05e0c9541aeb76e23597.zip

    yum install -y --enablerepo=epel slipstream-client
}

function deploy_SlipStreamServer () {
    echo "Deploying SlipStream..."

    service slipstream stop || true

    yum install -y slipstream-server

    update_slipstream_configuration

    deploy_CloudConnectors

    chkconfig --add slipstream
    service slipstream start

    deploy_nginx_proxy

    load_slipstream_examples
}

function update_slipstream_configuration() {

    sed -i -e "/^[a-z]/ s/slipstream.sixsq.com/${SS_HOSTNAME}/" \
           -e "/^[a-z]/ s/example.com/${SS_HOSTNAME}/" \
           $SLIPSTREAM_CONF

    _update_or_add_config_property slipstream.base.url https://${SS_HOSTNAME}/
    _update_or_add_config_property cloud.connector.orchestrator.publicsshkey /opt/slipstream/server/.ssh/id_rsa.pub
    _update_or_add_config_property cloud.connector.orchestrator.privatesshkey /opt/slipstream/server/.ssh/id_rsa

}

function _update_or_add_config_property() {
	PROPERTY=$1
	VALUE=$2
    SUBST_STR="$PROPERTY = $VALUE"
    grep -qP "^[ \t]*$PROPERTY" $SLIPSTREAM_CONF && \
        sed -i "s|$PROPERTY.*|$SUBST_STR|" $SLIPSTREAM_CONF || \
        echo $SUBST_STR >> $SLIPSTREAM_CONF
}

function deploy_nginx_proxy() {

    # Install nginx and the configuratoin file for SlipStream
    yum install -y slipstream-server-nginx-conf

}

function load_slipstream_examples() {
    isTrue $SLIPSTREAM_EXAMPLES || return 0

    sleep 5
    ss-module-upload -u ${SS_USERNAME} -p ${SS_PASSWORD} \
        --endpoint https://localhost /usr/share/doc/slipstream/*.xml
}

function deploy_CloudConnectors() {
     #yum -y install slipstream-connector* 
     echo "Installation of connectors is skipped."
}

function cleanup () {
    $CLEAN_PKG_CACHE
}

prepare_node
deploy_SlipStreamServerDependencies
deploy_SlipStreamClient
deploy_SlipStreamServer
cleanup

echo "::: SlipStream installed."

# HACKs go here
touch /opt/slipstream/connectors/bin/slipstream.client.conf

exit 0
