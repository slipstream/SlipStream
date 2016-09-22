#!/usr/bin/env bash
#
# SlipStream installation recipe.
# The installation works on RedHat based distribution only.
# The script does the following:
#  - installs SlipStream dependencies
#  - installs and starts RDBMS
#  - installs and starts SlipStream service (it's optionally possible not to
#  start the service).
# NB! Installation of the SlipStream connectors is not done in this script.

# Fail fast and fail hard.
set -e
set -o pipefail

# # # # # # #
# DEFAULTS.
# # # # # # #

VERBOSE=false
LOG_FILE=/tmp/slipstream-install.log

# Defult YUM repository kind.
_YUM_REPO_KIND_DEFAULT=release
declare -A _YUM_REPO_KIND_MAP
_YUM_REPO_KIND_MAP[local]=Local
_YUM_REPO_KIND_MAP[snapshot]=Snapshots
_YUM_REPO_KIND_MAP[candidate]=Candidates
_YUM_REPO_KIND_MAP[${_YUM_REPO_KIND_DEFAULT}]=Releases
SS_YUM_REPO_KIND=${_YUM_REPO_KIND_MAP[$_YUM_REPO_KIND_DEFAULT]}
SS_YUM_REPO_DEF_URL=

# Defult YUM repository edition.
_YUM_REPO_EDITIONS=(enterprise community)
SS_YUM_REPO_EDITION=community

SS_THEME=default
SS_LANG=en
SS_START=true

SS_DB=hsqldb

USAGE="usage: -h -v -l <log-file> -k <repo-kind> -e <repo-edition> -E -H <ip> -t <theme> -L <lang> -S\n
-h print this help\n
-v run in verbose mode\n
-l log file (default: $LOG_FILE)\n
-k kind of the repository to use: ${!_YUM_REPO_KIND_MAP[@]}. Default: $_YUM_REPO_KIND_DEFAULT\n
-e edition of the repository to use: ${_YUM_REPO_EDITIONS[@]}. Default: $SS_YUM_REPO_EDITION\n
-E don't load examples\n
-H hostname or IP of the host. If not provided, an attempt to discover it is made.\n
-t the theme for the service\n
-L the language of the interface. Possilbe values: en, fr, de, jp. (default: en)\n
-S don't start SlipStream service.\n
-x URL with the YUM repo definition file.\n
-d SlipStream RDBMS: hsqldb or postgresql. Default: $SS_DB"

# Allow this to be set in the environment to avoid having to pass arguments
# through all of the other installation scripts.
SLIPSTREAM_EXAMPLES=${SLIPSTREAM_EXAMPLES:-true}

function _exit_usage() {
    echo -e $USAGE
    exit 1
}

function _check_repo_edition() {
    if [ "$1" != "community" ] && [ "$1" != "enterprise" ]; then
       _exit_usage
    fi
}

function _check_repo_kind() {
    if ! test "${_YUM_REPO_KIND_MAP[$1]+isset}"; then
        _exit_usage
    fi
}

function _check_db_param() {
    if [ "$1" != "hsqldb" ] && [ "$1" != "postgresql" ]; then
       _exit_usage
    fi
}

while getopts l:H:t:L:k:e:d:x:vESh opt; do
    case $opt in
    v)
        VERBOSE=true
        ;;
    l)
        LOG_FILE=$OPTARG
        ;;
    k)
        _check_repo_kind $OPTARG
        SS_YUM_REPO_KIND=${_YUM_REPO_KIND_MAP[$OPTARG]}
        ;;
    e)
        _check_repo_edition $OPTARG
        SS_YUM_REPO_EDITION=$OPTARG
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
    S)
        # Don't start SlipStream service
        SS_START=false
        ;;
    x)
        SS_YUM_REPO_DEF_URL=$OPTARG
        ;;
    d)
        _check_db_param $OPTARG
        SS_DB=$OPTARG
        ;;
    *|h)
        _exit_usage
        ;;
    esac
done

SS_YUM_REPO=${SS_YUM_REPO_KIND}-${SS_YUM_REPO_EDITION}

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

function _print_error() {
    _print "ERROR! $@"
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

# apache-libcloud
CLOUD_CLIENT_LIBCLOUD_VERSION=0.18.0

# Packages from PyPi for SlipStream Client
PYPI_SCPCLIENT_VER=0.4

# PostgreSQL
# NB! Should correspond to the maven dependency version.
POSTGRESQL_VER=9.4
POSTGRESQL_REL=1
POSTGRESQL_RHEL=7.1
POSTGRESQL_USER=postgres
POSTGRESQL_PASS=password
POSTGRESQL_DBS="slipstream ssclj"

# Riemann variables.
RIEMANN_VER=0.2.11-1
ss_clj_client=/opt/slipstream/riemann/lib/SlipStreamServiceOfferAPI.jar
ss_riemann_conf=/etc/riemann/riemann-slipstream.config
ss_riemann_streams=/opt/slipstream/riemann/streams

# Elasticsearch
ES_HOST=localhost
ES_PORT=9300

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

SLIPSTREAM_ETC=/etc/slipstream
SLIPSTREAM_CONF=$SLIPSTREAM_ETC/slipstream.conf

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

function _ss_rpm_name_decorator() {
    # Decorate RPM names with -[yum-repo-edition]
    names=''
    for v in $@; do
        if [[ $v == slipstream* ]] && [[ $v != *-$SS_YUM_REPO_EDITION ]] ; then
            names="$names $v-$SS_YUM_REPO_EDITION"
        else
            names="$names $v"
        fi
    done
    echo $names
}

function _inst() {
    yum install -y $(_ss_rpm_name_decorator $@)
}

function srvc_start() {
    systemctl start $1
}
function srvc_stop() {
    systemctl stop $1
}
function srvc_restart() {
    systemctl restart $1
}
function srvc_enable() {
    systemctl enable $1
}
function srvc_mask() {
    systemctl mask $1
}
function srvc_() {
    systemctl $@
}

function _now_sec() {
    date +%s
}

function _wait_listens() {
    # host port [timeout seconds] [sleep interval seconds]
    wait_time=${3:-60}
    sleep_interval=${4:-2}
    stop_time=$(($(_now_sec) + $wait_time))
    while (( "$(_now_sec)" <= $stop_time )); do
        ncat -v -4 $1 $2 < /dev/null
        if [ "$?" == "0" ]; then
            return 0
        fi
        sleep $sleep_interval
    done
    abort "Timed out after ${wait_time} sec waiting for $1:$2"
}


function _configure_firewall () {
    _is_true $CONFIGURE_FIREWALL || return 0

    _print "- configuring firewall"

    # firewalld may not be installed
    srvc_stop firewalld || true
    srvc_mask firewalld || true

    _inst iptables-services
    srvc_enable iptables

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
    srvc_start iptables
}

function _add_yum_repos () {
    _print "- adding YUM repositories (EPEL, Nginx, Elasticsearch, SlipStream)"

    _inst yum-utils

    # EPEL
    _inst epel-release
    yum-config-manager --enable epel

    # Nginx
    nginx_repo_rpm=nginx-release-centos-7-0.el7.ngx.noarch.rpm
    rpm -Uvh --force \
        http://nginx.org/packages/centos/7/noarch/RPMS/${nginx_repo_rpm}

    # SlipStream
    if [ -n "$SS_YUM_REPO_DEF_URL" ]; then
        curl -o /etc/yum.repos.d/slipstream.repo $SS_YUM_REPO_DEF_URL
        SS_YUM_REPO=$(yum repolist enabled | grep -i slipstream | awk '{print $2}')
    else
        rpm -Uvh --force https://yum.sixsq.com/slipstream-repos-latest.noarch.rpm
        yum-config-manager --disable SlipStream-*
        yum-config-manager --enable SlipStream-${SS_YUM_REPO}
    fi

    # Elasticsearch repo configuration is available in SlipStream repo
    yum install -y 'slipstream-es-repo-*'
}

function _install_global_dependencies() {

    _print "- installing dependencies"

    _inst $DEPS
}

function _configure_selinux() {

    _print "- configuring selinux"

    # install SELinux needed utility tools
    _inst policycoreutils policycoreutils-python

    # if not disabled, configure SELinux in permissive mode
    if [[ "$(getenforce)" != "Disabled" ]]; then

        sed -i -e 's/^SELINUX=.*/SELINUX=permissive/' /etc/sysconfig/selinux \
            /etc/selinux/config

        setenforce Permissive

        # configure SELinux to work with SlipStream server
        setsebool -P httpd_run_stickshift 1
        setsebool -P httpd_can_network_connect 1
        semanage fcontext -a -t httpd_cache_t "/tmp/slipstream(/.*)?"
        restorecon -R -v /tmp/slipstream || true
    fi
}

function _install_time_sync_service() {
    _inst chrony
    srvc_start chronyd.service
    srvc_enable chronyd.service
}

function prepare_node () {

    _print "Preparing node"

    _add_yum_repos
    _install_global_dependencies
    _configure_firewall
    _configure_selinux
    _install_time_sync_service
}

function _deploy_postgresql () {

    _print "- installing PostgreSQL"

    VER=${POSTGRESQL_VER//.}
    rpm -iUvh \
        http://yum.postgresql.org/$POSTGRESQL_VER/redhat/rhel-$POSTGRESQL_RHEL-x86_64/pgdg-centos$VER-$POSTGRESQL_VER-$POSTGRESQL_REL.noarch.rpm

    _inst --nogpgcheck --enablerepo=pgdg$VER \
        postgresql$VER \
        postgresql$VER-server \
        postgresql$VER-libs \
        postgresql$VER-contrib

    srvc_enable postgresql-$POSTGRESQL_VER

    # start
    srvc_ initdb postgresql-$POSTGRESQL_VER
    srvc_start postgresql-$POSTGRESQL_VER

    # post-install configuration
    sed -i \
        -e '/^local.*all.*all.*/ s/^#*/#/' \
        -e '/^host.*all.*127.0.0.1\/32.*/ s/^#*/#/' \
        -e '/^host.*all.*::1\/128.*/ s/^#*/#/' \
         /var/lib/pgsql/$POSTGRESQL_VER/data/pg_hba.conf
   cat >> /var/lib/pgsql/$POSTGRESQL_VER/data/pg_hba.conf<<EOF
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
EOF
    srvc_restart postgresql-$POSTGRESQL_VER

    for db_name in $POSTGRESQL_DBS; do
        su - postgres -c "createdb $db_name"
    done
    su - postgres -c "psql -c \"ALTER ROLE ${POSTGRESQL_USER} WITH PASSWORD '"${POSTGRESQL_PASS}"'\";"
}

function _deploy_hsqldb () {

    _print "- installing HSQLDB"

    srvc_stop hsqldb || true
    kill -9 $(cat /var/run/hsqldb.pid) || true
    rm -f /var/run/hsqldb.pid

    _inst slipstream-hsqldb

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

    srvc_start hsqldb
}

function _deploy_graphite () {
    _print "- installing Graphite"

    _inst slipstream-graphite
}

function deploy_slipstream_server_deps () {

    _print "Installing SlipStream dependencies"

    _deploy_elasticsearch

    if [ "$SS_DB" = "postgresql" ]; then
        _deploy_postgresql
    elif [ "$SS_DB" = "hsqldb" ]; then
        _deploy_hsqldb
    else
        _print_error "Unsupported RDBMS provided: $SS_DB"
        _exit_usage
    fi
    _deploy_graphite
}

function deploy_slipstream_client () {

    _print "Installing SlipStream client"

    # Required by SlipStream cloud clients CLI
    pip install -Iv apache-libcloud==${CLOUD_CLIENT_LIBCLOUD_VERSION}

    # Required by SlipStream ssh utils
    pip install -Iv scpclient==$PYPI_SCPCLIENT_VER

    # winrm
    winrm_pkg=a2e7ecf95cf44535e33b05e0c9541aeb76e23597.zip
    pip install https://github.com/diyan/pywinrm/archive/${winrm_pkg}

    _inst slipstream-client
}

function deploy_slipstream_server () {

    _print "Installing SlipStream server"

    _stop_slipstream_service

    _print "- installing and configuring SlipStream service"
    _inst slipstream-server

    _update_slipstream_configuration

    _set_theme
    _set_localization
    _set_elasticsearch_coords

    _start_slipstream
    _enable_slipstream

    _deploy_nginx_proxy

    _load_slipstream_examples
}

function _set_elasticsearch_coords() {
    _set_jetty_args es.host $ES_HOST
    _set_jetty_args es.port $ES_PORT
}

function _set_theme() {
    # do not write this line if using the default theme for now
    if [ -n $SS_THEME -a "X$SS_THEME" -ne "Xdefault" ]; then
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

    srvc_stop slipstream || true
    srvc_stop ssclj || true
}

function _start_slipstream() {
    if ( _is_true $SS_START ); then
        _print "- starting SlipStream service"
        _start_slipstream_service
        _start_slipstream_application
    else
        _print "- WARNING: requested not to start SlipStream service"
    fi
}

function _start_slipstream_service() {
    srvc_start ssclj
    srvc_start slipstream
}

function _enable_slipstream() {
    srvc_enable ssclj
    srvc_enable slipstream
}

function _start_slipstream_application() {
    _wait_listens $SS_LOCAL_HOST $SS_LOCAL_PORT
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

function _update_hostname_in_conf_file() {
    # $@ names of the files to update
    sed -i -e "/^[a-z]/ s/nuv.la/${SS_HOSTNAME}/" \
           -e "/^[a-z]/ s/example.com/${SS_HOSTNAME}/" \
           -e "/^[a-z]/ s/<CHANGE_HOSTNAME>/${SS_HOSTNAME}/" \
           $@
}

function _update_slipstream_configuration() {

    for ssconf in $(find $SLIPSTREAM_ETC -maxdepth 1 -name "$(basename $SLIPSTREAM_CONF)*" -type f); do
        _update_hostname_in_conf_file $ssconf
    done

    if [ -d $SLIPSTREAM_ETC/connectors ]; then
        for cconf in $(find $SLIPSTREAM_ETC/connectors -name "*.conf"); do
            _update_hostname_in_conf_file $cconf
        done
    fi

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

function _deploy_elasticsearch() {

    _print "- install elasticsearch"

    # Install elasticsearch with explicit java dependency
    _inst java-1.8.0-openjdk-headless
    _inst elasticsearch

    # Configure elasticsearch
    # FIXME: visible on localhost only
    elasticsearch_cfg=/etc/elasticsearch/elasticsearch.yml
    mv ${elasticsearch_cfg} ${elasticsearch_cfg}.orig
    cat > ${elasticsearch_cfg} <<EOF
network.host: 127.0.0.1
# AWS configuration
cloud:
  aws:
    access_key: CHANGE_ME_ID
    secret_key: CHANGE_ME_KEY
EOF

    # Ensure is started; start also on boot.
    srvc_enable elasticsearch.service
    srvc_start elasticsearch
}

function _deploy_nginx_proxy() {

    _print "- install nginx and nginx configuration for SlipStream"

    # Install nginx and the configuration file for SlipStream.
    _inst slipstream-server-nginx-conf
    srvc_start nginx
}

function _load_slipstream_examples() {
    _is_true $SS_START || return 0
    _is_true $SLIPSTREAM_EXAMPLES || return 0

    _print "- loading SlipStream examples"
    ss-module-upload -u ${SS_USERNAME} -p ${SS_PASSWORD} \
        --endpoint $SS_LOCAL_URL /usr/share/doc/slipstream/*.xml
}


##
## Install Placement and Ranking service
function deploy_prs_service() {
  [ "$SS_YUM_REPO_EDITION" != "enterprise" ] && return 0
  _print "Installing Placement and Ranking service"
  _inst slipstream-pricing-server-enterprise
  srvc_enable ss-pricing
  srvc_start ss-pricing
}


##
## Riemann installation.
function _install_riemann() {
    yum localinstall -y https://aphyr.com/riemann/riemann-${RIEMANN_VER}.noarch.rpm
    srvc_enable riemann
}

function _add_ss_riemann_streams() {
    cat > $ss_riemann_conf<<EOF
; -*- mode: clojure; -*-
; vim: filetype=clojure

(logging/init {:file "/var/log/riemann/riemann.log"})

; Listen on the local interface over TCP (5555).
; Disable UDP (5555), and websockets (5556).
(let [host "127.0.0.1"]
  (tcp-server {:host host})
  #_(udp-server {:host host})
  #_(ws-server  {:host host}))

; Location of SlipStream Riemann streams.
(include "$ss_riemann_streams")
EOF
    cat >> /etc/sysconfig/riemann<<EOF
EXTRA_CLASSPATH=$ss_clj_client
RIEMANN_CONFIG=$ss_riemann_conf
EOF
}

function deploy_riemann() {
  [ "$SS_YUM_REPO_EDITION" != "enterprise" ] && return 0
  _print "Installing Riemann"
  _inst slipstream-riemann-enterprise
  _install_riemann
  _add_ss_riemann_streams
  srvc_start riemann
}

function cleanup () {
    $CLEAN_PKG_CACHE
}

set -u
set -x

_print $(date)
_print "Starting installation of SlipStream server (from ${SS_YUM_REPO})."

prepare_node
deploy_slipstream_server_deps
deploy_slipstream_client
deploy_slipstream_server
deploy_prs_service
deploy_riemann
cleanup

function _how_to_start_service() {
    declare -f _start_slipstream_service | awk '/{/{x=1;next}/}/{x=0}x'
}

if ( _is_true $SS_START ); then
    _print "SlipStream server installed and accessible at https://$SS_HOSTNAME"
else
    _print "SlipStream server installed, but wasn't started."
    _print "To start the service run:\n$(_how_to_start_service)"
    _print "SlipStream server will become accessible at https://$SS_HOSTNAME"
fi
_print "Please see Configuration section of the SlipStream administrator
manual for the next steps like changing the service default passwords,
adding cloud connectors and more."
_print "$(date)"

exit 0
