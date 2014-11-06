#!/usr/bin/env bash
#
# SlipStream 2.3 PROD installation recipe

# Fail fast and fail hard.
set -e
set -o pipefail
set -x

VERBOSE=false
LOG_FILE=/tmp/slipstream-install.log
# Type of repository to lookup for SlipStream packages. 'Releases' will install
# stable releases, whereas 'Snapshots' will install unstable/testing packages.
SS_REPO_KIND=Releases

while getopts l:sv opt; do
    case $opt in
    v)
        VERBOSE=true
        ;;
    l)
        LOG_FILE=$OPTARG
        ;;
    s)
        # Use Snapshots repo
        SS_REPO_KIND=Snapshots
        ;;
    *)
        ;;
    esac
done

shift $((OPTIND - 1))

if [ "$VERBOSE" = "true" ]; then
    exec 4>&2 3>&1
else
    exec 4>&2 3>&1 1>>${LOG_FILE} 2>&1
fi

# # # # # # #
# Utilities.
# # # # # # #

function abort() {
    echo "!!! Aborting: $@" 1>&4
    exit 1
}

function _print() {
    echo -e "::: $@" 1>&3
}

function _print_on_trap() {
    if [ "$VERBOSE" != "true" ]; then
        _print "ERROR! Check log file ${LOG_FILE}\n... snippet ...\n$(tail -5 ${LOG_FILE})"
    fi
}

function _on_trap() {
    _print_on_trap
}

trap '_on_trap' ERR

# Return first global IPv4 address.
function _get_hostname() {
    ip addr | awk '/inet .*global/ { split($2, x, "/"); print x[1] }' | head -1
}

# # # # # # # # # # #
# Global parameters.
# # # # # # # # # # #

# First "global" IPv4 address
SS_HOSTNAME=$(_get_hostname)
[ -z "${SS_HOSTNAME}" ] && \
    abort "Could not determinee IP or hostname of the public interface
SlipStream will running on."

# libcloud
CLOUD_CLIENT_LIBCLOUD_VERSION=0.14.1

# EPEL repository
EPEL_VER=6-8

# Packages from PyPi for SlipStream Client
PYPI_PARAMIKO_VER=1.9.0
PYPI_SCPCLIENT_VER=0.4

# # # # # # # # # # # #
# Advanced parameters.
# # # # # # # # # # # #

CONFIGURE_FIREWALL=true

SLIPSTREAM_EXAMPLES=true
SS_USERNAME=sixsq
# Deafult.  Should be changed immenidately after installation.
# See SlipStream administrator manual.
SS_PASSWORD=siXsQsiXsQ

SLIPSTREAM_CONF=/etc/slipstream/slipstream.conf

DEPS="unzip curl wget gnupg nc python-pip"
CLEAN_PKG_CACHE="yum clean all"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Deployment.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

alias cp='cp'

function _is_true() {
    if [ "x${1}" == "xtrue" ]; then
        return 0
    else
        return 1
    fi
}

function _configure_firewall () {
    _is_true $CONFIGURE_FIREWALL || return 0

    _print "- configuring firewall"

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
    _print "- adding YUM repositories (EPEL, Nginx, SlipStream)"

    # EPEL
    epel_repo_rpm=epel-release-${EPEL_VER}.noarch.rpm
    rpm -Uvh --force \
        http://mirror.switch.ch/ftp/mirror/epel/6/i386/${epel_repo_rpm}
    sed -i -e 's/^#baseurl=/baseurl=/' -e 's/^mirrorlist=/#mirrorlist=/' /etc/yum.repos.d/epel.repo

    # Nginx
    nginx_repo_rpm=nginx-release-centos-6-0.el6.ngx.noarch.rpm
	rpm -Uvh --force \
        http://nginx.org/packages/centos/6/noarch/RPMS/${nginx_repo_rpm}

    # SlipStream
    ss_repo_rpm=slipstream-repos-1.0-1.noarch.rpm
	rpm -Uvh --force \
        http://yum.sixsq.com/slipstream/centos/6/${ss_repo_rpm}
    
    yum install -y yum-utils
    yum-config-manager --disable SlipStream-*
    yum-config-manager --enable SlipStream-${SS_REPO_KIND}
}

function _install_global_dependencies() {

    _print "- installing dependencies"

    yum install -y --enablerepo=epel $DEPS

}

function _disable_selinux() {

    _print "- disabling selinux"

    echo 0 > /selinux/enforce
    sed -i -e 's/^SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux \
        /etc/selinux/config
}

function prepare_node () {

    _print "Preparing node"

    _add_yum_repos
    _install_global_dependencies
    _configure_firewall
    _disable_selinux
}

function _deploy_hsqldb () {

    _print "- installing HSQLDB"

    service hsqldb stop || true
    kill -9 $(cat /var/run/hsqldb.pid) || true
    rm -f /var/run/hsqldb.pid

    yum install -y slipstream-hsqldb

    # FIXME: hsqldb init script exits with 1.
    service hsqldb start || true # false-positive failure
}

function deploy_slipstream_server_deps () {

    _print "Installing dependencies"

    _deploy_hsqldb
}

function deploy_slipstream_client () {

    _print "Installing SlipStream client"

    # Required by SlipStream cloud clients CLI
    pip install -Iv apache-libcloud==${CLOUD_CLIENT_LIBCLOUD_VERSION}

    # Required by SlipStream ssh utils
    yum install -y gcc python-devel
    # python-crypto clashes with Crypto installed as dependency with paramiko
    yum remove -y python-crypto
    pip install -Iv paramiko==$PYPI_PARAMIKO_VER
    pip install -Iv scpclient==$PYPI_SCPCLIENT_VER

    # winrm
    winrm_pkg=a2e7ecf95cf44535e33b05e0c9541aeb76e23597.zip
    pip install https://github.com/diyan/pywinrm/archive/${winrm_pkg}

    yum install -y --enablerepo=epel slipstream-client
}

function deploy_slipstream_server () {

    _print "Installing SlipStream server"

    service slipstream stop || true

    yum install -y slipstream-server

    update_slipstream_configuration

    _deploy_cloud_connectors

    chkconfig --add slipstream
    service slipstream start

    _deploy_nginx_proxy

    _load_slipstream_examples
}

function update_slipstream_configuration() {

    sed -i -e "/^[a-z]/ s/slipstream.sixsq.com/${SS_HOSTNAME}/" \
           -e "/^[a-z]/ s/example.com/${SS_HOSTNAME}/" \
           $SLIPSTREAM_CONF

    _update_or_add_config_property slipstream.update.clienturl \
        https://${SS_HOSTNAME}/downloads/slipstreamclient.tgz
    _update_or_add_config_property slipstream.update.clientbootstrapurl \
        https://${SS_HOSTNAME}/downloads/slipstream.bootstrap
    _update_or_add_config_property cloud.connector.library.libcloud.url \
        https://${SS_HOSTNAME}/downloads/libcloud.tgz
    _update_or_add_config_property slipstream.base.url https://${SS_HOSTNAME}
    _update_or_add_config_property cloud.connector.orchestrator.publicsshkey \
        /opt/slipstream/server/.ssh/id_rsa.pub
    _update_or_add_config_property cloud.connector.orchestrator.privatesshkey \
        /opt/slipstream/server/.ssh/id_rsa
}

function _update_or_add_config_property() {
	PROPERTY=$1
	VALUE=$2
    SUBST_STR="$PROPERTY = $VALUE"
    grep -qP "^[ \t]*$PROPERTY" $SLIPSTREAM_CONF && \
        sed -i "s|$PROPERTY.*|$SUBST_STR|" $SLIPSTREAM_CONF || \
        echo $SUBST_STR >> $SLIPSTREAM_CONF
}

function _deploy_nginx_proxy() {

    _print "- install nginx and nginx configuration for SlipStream"

    # Install nginx and the configuratoin file for SlipStream
    yum install -y slipstream-server-nginx-conf
    service nginx start

}

function _load_slipstream_examples() {
    _is_true $SLIPSTREAM_EXAMPLES || return 0

    sleep 5
    _print "- loading SlipStream examples"
    ss-module-upload -u ${SS_USERNAME} -p ${SS_PASSWORD} \
        --endpoint https://localhost /usr/share/doc/slipstream/*.xml
}

function _deploy_cloud_connectors() {
     _print "- installing SlipStream connectors"
     #yum -y install slipstream-connector*
     _print "---> WARNING: Skipped installation of SlipStream connectors."
}

function cleanup () {
    $CLEAN_PKG_CACHE
}

set -u

_print $(date)
_print "Starting installation of SlipStream server."

prepare_node
deploy_slipstream_server_deps
deploy_slipstream_client
deploy_slipstream_server
cleanup

_print "SlipStream server installed and accessible at https://$SS_HOSTNAME"
_print "Please see Configuration section of the SlipStream administrator
manual for the next steps like changing the service default passwords,
adding cloud connectors and more."
_print "$(date)"

exit 0
