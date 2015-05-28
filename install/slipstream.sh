#!/usr/bin/env bash
#
# SlipStream installation recipe

# Fail fast and fail hard.
set -e
set -o pipefail

VERBOSE=false
LOG_FILE=/tmp/slipstream-install.log
# Type of repository to lookup for SlipStream packages. 'Releases' will install
# stable releases, whereas 'Snapshots' will install unstable/testing packages.
SS_REPO_KIND=Releases-community
SS_THEME=
SS_LANG=

# Allow this to be set in the environment to avoid having to pass arguments
# through all of the other installation scripts.
SLIPSTREAM_EXAMPLES=${SLIPSTREAM_EXAMPLES:-true}

while getopts l:H:t:L:s:vE opt; do
    case $opt in
    v)
        VERBOSE=true
        ;;
    l)
        LOG_FILE=$OPTARG
        ;;
    s)
        SS_REPO_KIND=$OPTARG
        ;;
    E)
        # Do not upload examples
        SLIPSTREAM_EXAMPLES=false
        ;;
    H)
        # hostname/ip
        SS_HOSTNAME=$OPTARG
        ;;
    t)
        # Theme name
        SS_THEME=$OPTARG
        ;;
    L)
        # Localization language
        SS_LANG=$OPTARG
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
SS_HOSTNAME=${SS_HOSTNAME:-$(_get_hostname)}
[ -z "${SS_HOSTNAME}" ] && \
    abort "Could not determinee IP or hostname of the public interface
for SlipStream to run on."

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

SS_USERNAME=super
# Deafult.  Should be changed immediately after installation.
# See SlipStream administrator manual.
SS_PASSWORD=supeRsupeR

# Default local coordinates of SlipStream.
SS_LOCAL_PORT=8182
SS_LOCAL_HOST=localhost
SS_LOCAL_URL=http://$SS_LOCAL_HOST:$SS_LOCAL_PORT

SLIPSTREAM_CONF=/etc/slipstream/slipstream.conf

DEPS="unzip curl wget gnupg nc python-pip"
CLEAN_PKG_CACHE="yum clean all"

SS_JETTY_CONFIG=/etc/default/slipstream

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
    rpm -e epel-release || true
    epel_repo_rpm=epel-release-${EPEL_VER}.noarch.rpm
    rpm -Uvh --force \
        http://mirror.switch.ch/ftp/mirror/epel/6/i386/${epel_repo_rpm}
    sed -i -e 's/^#baseurl=/baseurl=/' -e 's/^mirrorlist=/#mirrorlist=/' /etc/yum.repos.d/epel.repo

    # Nginx
    nginx_repo_rpm=nginx-release-centos-6-0.el6.ngx.noarch.rpm
	rpm -Uvh --force \
        http://nginx.org/packages/centos/6/noarch/RPMS/${nginx_repo_rpm}

    # SlipStream
    rpm -Uvh --force https://yum.sixsq.com/slipstream-repos-latest.noarch.rpm

    yum install -y yum-utils
    yum-config-manager --disable SlipStream-*
    yum-config-manager --enable SlipStream-${SS_REPO_KIND}
    yum-config-manager --enable epel
}

function _install_global_dependencies() {

    _print "- installing dependencies"

    yum install -y $DEPS

}

function _disable_selinux() {

    _print "- disabling selinux"

    echo 0 > /selinux/enforce
    sed -i -e 's/^SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux \
        /etc/selinux/config
}

function _install_ntp() {
    yum install -y ntp
    service ntpd start
    chkconfig --add ntpd
    chkconfig ntpd on
}

function prepare_node () {

    _print "Preparing node"

    _add_yum_repos
    _install_global_dependencies
    _configure_firewall
    _disable_selinux
    _install_ntp
}

function _deploy_hsqldb () {

    _print "- installing HSQLDB"

    service hsqldb stop || true
    kill -9 $(cat /var/run/hsqldb.pid) || true
    rm -f /var/run/hsqldb.pid

    yum install -y slipstream-hsqldb

    cat > ~/sqltool.rc <<EOF
urlid slipstream
url jdbc:hsqldb:hsql://localhost:9001/slipstream
username sa
password

urlid ssclj
url jdbc:hsqldb:hsql://localhost:9001/ssclj
username sa
password
EOF

    service hsqldb start
}

function _deploy_graphite () {
    _print "- installing Graphite"

    yum install -y slipstream-graphite
}

function deploy_slipstream_server_deps () {

    _print "Installing dependencies"

    _deploy_hsqldb
    _deploy_graphite
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

    yum install -y slipstream-client
}

function deploy_slipstream_server () {

    _print "Installing SlipStream server"

    _stop_slipstream_service

    yum install -y slipstream-server

    _update_slipstream_configuration

    _deploy_cloud_connectors

    _set_theme
    _set_localization

    _start_slipstream_service

    _deploy_nginx_proxy

    _load_slipstream_examples
}

function _set_theme() {
    if [ -n $SS_THEME ]; then
        _set_jetty_args slipstream.ui.util.theme.current-theme $SS_THEME
    fi
}

function _set_localization() {
    if [ -n $SS_LANG ]; then
        _set_jetty_args slipstream.ui.util.localization.lang-default $SS_LANG
    fi
}

function _stop_slipstream_service() {
    _print "- stopping SlipStream service"

    service slipstream stop || true
    service ssclj stop || true
}

function _start_slipstream_service() {
    _print "- starting SlipStream service"

    chkconfig --add ssclj
    service ssclj start

    chkconfig --add slipstream
    service slipstream start

    _start_slipstream_application
}

function _start_slipstream_application() {
    set +e
    while true; do
        nc -v -z $SS_LOCAL_HOST $SS_LOCAL_PORT
        if [ "$?" == "0" ]; then
            break
        fi
        sleep 2
    done
    set -e
    curl -m 60 -S -o /dev/null $SS_LOCAL_URL
}

function _set_jetty_args() {
    prop_name=$1
    prop_value=${2:-""}
    if ( ! grep -q -- "-D$prop_name=" ${SS_JETTY_CONFIG} ); then
        cat >> ${SS_JETTY_CONFIG} <<EOF
export JETTY_ARGS="\$JETTY_ARGS -D$prop_name=$prop_value"
EOF
    elif ( ! grep -q -- "-D$prop_name=$prop_value" ${SS_JETTY_CONFIG} ); then
            sed -i -e "s/-D$prop_name=[a-zA-Z0-9]*[ \t]*/-D$prop_name=$prop_value /" ${SS_JETTY_CONFIG}
    fi
}

function _update_slipstream_configuration() {

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

    _print "- loading SlipStream examples"
    ss-module-upload -u ${SS_USERNAME} -p ${SS_PASSWORD} \
        --endpoint $SS_LOCAL_URL /usr/share/doc/slipstream/*.xml
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
set -x

_print $(date)
_print "Starting installation of SlipStream server (from ${SS_REPO_KIND})."

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
