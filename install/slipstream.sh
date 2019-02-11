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
set -x
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

SS_SERVER_LOC=/opt/slipstream/server
SS_SERVER_LOG_DIR=/var/log/slipstream/server

# Elasticsearch via transport client on localhost.
export ES_HOST=localhost
export ES_PORT_BIN=9300
export ES_PORT_HTTP=9200
export ES_PORT=$ES_PORT_BIN
ES_INSTALL=true

# Logstash coordinates.
SS_LOGSTASH_COLLECTD_UDP=25826
export LOGSTASH_HOST=localhost
export LOGSTASH_PORT=5043
LOGSTASH_INSTALL=true

ELK_XPACK=false

# Zookeeper coordinates.
export ZK_ENDPOINTS=localhost:2181

USAGE="usage: -h -v -l <log-file> -k <repo-kind> -e <repo-edition> -E -H <ip> -t <theme> -L <lang> \n
-S -a <es_host:port> -b <logstash_host:port> -c\n
\n
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
-a Elasticsearch coordinates. Default: $ES_HOST:$ES_PORT. If provided, and\n
   hostname/IP is localhost or 127.0.0.1, then Elasticsearch will be installed.\n
-b Logstash coordinates. Default: $LOGSTASH_HOST:$LOGSTASH_PORT.  If provided,\n
   and hostname/IP is localhost or 127.0.0.1, then Logstash will be installed.\n
-c If provided, install X-Pack for ELK components.\n
-z Zookeeper coordinates. Default: $ZK_ENDPOINTS. If provided,\n
   and hostname/IP is localhost or 127.0.0.1, then Zookeeper will be installed.\n"

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

function _is_local_install() {
   if [[ $1 =~ (localhost|127.0.0.1) ]]; then
      echo true
   else
      echo false
   fi
}

while getopts a:b:l:H:t:L:k:e:d:x:vESch opt; do
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
      a)
         ES_HOST=${OPTARG%%:*}
         ES_PORT=${OPTARG#*:}
         ES_INSTALL=$(_is_local_install $ES_HOST)
         ;;
      b)
         LOGSTASH_HOST=${OPTARG%%:*}
         LOGSTASH_PORT=${OPTARG#*:}
         LOGSTASH_INSTALL=$(_is_local_install $LOGSTASH_HOST)
         ;;
      c)
         ELK_XPACK=true
         ;;
      *|h)
         _exit_usage
         ;;
   esac
done

SS_YUM_REPO=${SS_YUM_REPO_KIND}-${SS_YUM_REPO_EDITION}
SS_YUM_REPO_COMMUNITY=${SS_YUM_REPO_KIND}-community

shift $((OPTIND - 1))

VERBOSE=true
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
function _get_ip() {
   ip addr | awk '/inet .*global/ { split($2, x, "/"); print x[1] }' | head -1
}

# # # # # # # # # # #
# Global parameters.
# # # # # # # # # # #

# First "global" IPv4 address
HOST_IP=$(_get_ip)
SS_HOSTNAME=${SS_HOSTNAME:-$HOST_IP}
[ -z "${SS_HOSTNAME}" ] && \
   abort "Could not determinee IP or hostname of the public interface
for SlipStream to run on."

# apache-libcloud
CLOUD_CLIENT_LIBCLOUD_VERSION=0.18.0

# Packages from PyPi for SlipStream Client
PYPI_SCPCLIENT_VER=0.4

# Riemann variables.
RIEMANN_VER=0.2.11-1
ss_clj_client=/opt/slipstream/riemann/lib/SlipStreamRiemann.jar
ss_riemann_conf=/etc/riemann/riemann-slipstream.config
ss_riemann_streams=/opt/slipstream/riemann/streams

# # # # # # # # # # # #
# Advanced parameters.
# # # # # # # # # # # #

CONFIGURE_FIREWALL=true

SS_USERNAME=super
# Deafult.  Should be changed immediately after installation.
# See SlipStream administrator manual.
SS_PASSWORD=supeRsupeR

if [ -f /etc/slipstream/passwords/$SS_USERNAME ]; then
   SS_PASSWORD=$(cat /etc/slipstream/passwords/$SS_USERNAME)
fi

# Default local coordinates of SlipStream.
SS_LOCAL_PORT=8182
SS_LOCAL_HOST=localhost
SS_LOCAL_URL=http://$SS_LOCAL_HOST:$SS_LOCAL_PORT

CIMI_LOCAL_HOST=localhost
CIMI_LOCAL_PORT=8201
CIMI_LOCAL_URL=http://$CIMI_LOCAL_HOST:$CIMI_LOCAL_PORT

SLIPSTREAM_ETC=/etc/slipstream
SLIPSTREAM_CONF=$SLIPSTREAM_ETC/slipstream.edn

DEPS="unzip curl wget gnupg nc python-pip"
CLEAN_PKG_CACHE="yum clean all"

SS_JETTY_CONFIG=/etc/default/slipstream

SS_USER=slipstream
SS_GROUP=$SS_USER

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

function _inst() {
   yum install -y $@
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
      set +e
      res=$(ncat -v -4 $1 $2 < /dev/null 2>&1)
      if [ "$?" == "0" ]; then
         set -e
         return 0
      else
         if ( ! (echo $res | grep -q "Connection refused") ); then
            abort "Failed to check $1:$2 with:" $res
         fi
      fi
      set -e
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
-A INPUT -m state --state NEW -m tcp -p tcp --dport 5601 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF
   srvc_start iptables
}

function _add_yum_repos () {
   _print "- adding YUM repositories (EPEL, Nginx, Elasticstack, SlipStream)"

   _inst yum-utils

   # EPEL
   _inst epel-release
   yum-config-manager --enable epel

   # Nginx
   nginx_repo_rpm=nginx-release-centos-7-0.el7.ngx.noarch.rpm
   rpm -Uvh --force \
      http://nginx.org/packages/centos/7/noarch/RPMS/${nginx_repo_rpm}

   # SlipStream (enterprise now requires community repository as well)
   if [ -n "$SS_YUM_REPO_DEF_URL" ]; then
      curl -o /etc/yum.repos.d/slipstream.repo $SS_YUM_REPO_DEF_URL
      SS_YUM_REPO=$(yum repolist enabled | grep -i slipstream | awk '{print $2}')
   else
      rpm -Uvh --force https://yum.sixsq.com/slipstream-repos-latest.noarch.rpm
      yum-config-manager --disable SlipStream-*
      yum-config-manager --enable SlipStream-${SS_YUM_REPO}
      yum-config-manager --enable SlipStream-${SS_YUM_REPO_COMMUNITY}
   fi

   # Elasticstack repo configuration is available in SlipStream repo
   yum install -y 'slipstream-es-repo'
}

function _install_global_dependencies() {

   _print "- installing dependencies"

   _inst $DEPS
}

function _configure_selinux() {

   _print "- configuring SELinux"

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
   _print "- installing time synchronization service"

   _inst chrony
   srvc_start chronyd.service
   srvc_enable chronyd.service
}

function _configure_hostname() {
   set +e
   hostname -f 1>/dev/null 2>&1
   if [ $? -ne 0 ]; then
      getent hosts $HOST_IP 1>/dev/null 2>&1
      if [ $? -ne 0 ] ; then
         echo "$HOST_IP $(hostname)" >> /etc/hosts
      fi
   fi
   set -e
}

function prepare_node () {

   _print "Preparing node"

   _add_yum_repos
   _install_global_dependencies
   _configure_firewall
   _configure_selinux
   _install_time_sync_service
   _configure_hostname
}

function _deploy_haveged () {

   _print "- installing haveged (entropy generator)"

   srvc_stop haveged || true

   _inst haveged

   srvc_enable haveged

   srvc_start haveged
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
EOF

srvc_start hsqldb
}

function _deploy_graphite () {
   _print "- installing Graphite"

   _inst slipstream-graphite

   sed -i -e "s/__HOST_IP__/$HOST_IP/" /etc/carbon/storage-schemas.conf
   sed -i -e "s/WHISPER_SPARSE_CREATE.*/WHISPER_SPARSE_CREATE = True/" \
      /etc/carbon/carbon.conf
}

function _deploy_zookeeper() {
   _print "- installing Zookeeper"

   _inst https://archive.cloudera.com/cdh5/one-click-install/redhat/7/x86_64/cloudera-cdh-5-0.x86_64.rpm
   _inst zookeeper zookeeper-server

   mkdir -p /var/lib/zookeeper
   chown -R zookeeper /var/lib/zookeeper/

   /etc/rc.d/init.d/zookeeper-server init
   /etc/rc.d/init.d/zookeeper-server start
}

function deploy_slipstream_server_deps () {

   _print "Installing SlipStream dependencies"

   _deploy_haveged

   _deploy_elasticstack

   _deploy_hsqldb

   _deploy_graphite

   _deploy_zookeeper
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
   _set_zookeeper_coords

   _start_slipstream
   _enable_slipstream

   _deploy_nginx_proxy

   _load_slipstream_examples
   _upload_apikey_session_template
}

function _set_elasticsearch_coords() {
   sed -i -e "s/ES_HOST=.*/ES_HOST=$ES_HOST/" \
      -e "s/ES_PORT=.*/ES_PORT=$ES_PORT/" \
      /etc/default/cimi \
      /etc/default/slipstream
}

function _set_zookeeper_coords() {
   if ( grep -q ZK_ENDPOINTS /etc/default/cimi ); then
      sed -i -e "s/ZK_ENDPOINTS=.*/ZK_ENDPOINTS=$ZK_ENDPOINTS/" \
         /etc/default/cimi
   else
      echo "ZK_ENDPOINTS=$ZK_ENDPOINTS" >> /etc/default/cimi
   fi
}

function _set_theme() {
   # do not write this line if using the default theme for now
   if [ -n $SS_THEME -a "X$SS_THEME" != "Xdefault" ]; then
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
   srvc_stop cimi || true
}

function _start_slipstream() {
   if ( _is_true $SS_START ); then
      _print "- starting SlipStream service"
      _start_slipstream_service
   else
      _print "- WARNING: requested not to start SlipStream service"
   fi
}

function _start_cimi_application() {
   # CIMI (increased to 600 because of slow startup)
   _wait_listens $CIMI_LOCAL_HOST $CIMI_LOCAL_PORT 600
   curl -m 60 -sfS -o /dev/null $CIMI_LOCAL_URL/api/cloud-entry-point
}

function _start_ss_application() {
   # SS
   _wait_listens $SS_LOCAL_HOST $SS_LOCAL_PORT
   curl -m 60 -sfS -o /dev/null $SS_LOCAL_URL
}

function _start_slipstream_service() {
   srvc_start cimi
   _start_cimi_application
   srvc_start slipstream
   _start_ss_application
}

function _enable_slipstream() {
   srvc_enable cimi
   srvc_enable slipstream
}

function _start_slipstream_application() {
   _start_cimi_application
   _start_ss_application
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
   sed -i -e "s/nuv.la/${SS_HOSTNAME}/" \
      -e "s/example.com/${SS_HOSTNAME}/" \
      -e "s/<CHANGE_HOSTNAME>/${SS_HOSTNAME}/" \
      $@
}

function _chown_slipstream_etc() {
   chown -R $SS_USER.$SS_GROUP $SLIPSTREAM_ETC
}

function _update_service_configuration() {

   # Configuration.
   [ -s $SLIPSTREAM_CONF ] || printf "{\n}\n" > $SLIPSTREAM_CONF

   chown $SS_USER.$SS_GROUP $SLIPSTREAM_CONF

   _update_hostname_in_conf_file $SLIPSTREAM_CONF

   # Update configuration file.
   ss-config \
      -e id=configuration/slipstream \
      -e clientURL=https://${SS_HOSTNAME}/downloads/slipstreamclient.tgz \
      -e clientBootstrapURL=https://${SS_HOSTNAME}/downloads/slipstream.bootstrap \
      -e connectorLibcloudURL=https://${SS_HOSTNAME}/downloads/libcloud.tgz \
      -e serviceURL=https://${SS_HOSTNAME} \
      -e connectorOrchPublicSSHKey=$SS_SERVER_LOC/.ssh/id_rsa.pub \
      -e connectorOrchPrivateSSHKey=$SS_SERVER_LOC/.ssh/id_rsa \
      $SLIPSTREAM_CONF

   # Push service configuration to DB.
   ss-config $SLIPSTREAM_CONF
}

function _update_connectors_configuration() {
   # Connectors.
   SLIPSTREAM_CONNECTORS=
   if [ -d $SLIPSTREAM_ETC/connectors ]; then
      SLIPSTREAM_CONNECTORS=$(find $SLIPSTREAM_ETC/connectors -name "*.edn")
      for cconf in $SLIPSTREAM_CONNECTORS; do
         _update_hostname_in_conf_file $cconf
      done
   fi

   # NB! Pushing connectors configuration to DB can only be done when connectors are installed.
}

function _update_slipstream_configuration() {
   _chown_slipstream_etc
   _update_service_configuration
   _update_connectors_configuration
}

function _install_kibana() {
   _print "- installing Kibana"

   _inst java-1.8.0-openjdk-headless
   _inst kibana

   _is_true $ELK_XPACK && \
      /usr/share/kibana/bin/kibana-plugin install x-pack || true

   # SSL config. Steal certs from nginx.
   kibana_ssl=/etc/kibana/ssl
   if [ ! -d $kibana_ssl ]; then
      mkdir -p $kibana_ssl
      chmod 700 $kibana_ssl
      cp -p /etc/nginx/ssl/server.* $kibana_ssl
      chown -R kibana. $kibana_ssl
      chmod 400 $kibana_ssl/*
   fi

   log_dest=/var/log/kibana
   mkdir -p $log_dest
   chown -R kibana. $log_dest

   cat >> /etc/kibana/kibana.yml << EOF
server.ssl.cert: $kibana_ssl/server.crt
server.ssl.key:  $kibana_ssl/server.key
server.host: "0.0.0.0"
elasticsearch.url: "http://$ES_HOST:$ES_PORT_HTTP"
logging.dest: $log_dest/kibana.log
EOF

srvc_enable kibana.service
srvc_start kibana
}

function _install_elasticsearch() {
   _print "- installing Elasticsearch"

   _inst java-1.8.0-openjdk-headless
   _inst elasticsearch

   # For authn with Kibana and more.
   _is_true $ELK_XPACK && \
      /usr/share/elasticsearch/bin/elasticsearch-plugin install -b x-pack || true
   # To be added from elasticsearch v6.x

   mkdir -p /usr/share/elasticsearch/logs/
   chown -R elasticsearch:elasticsearch /usr/share/elasticsearch/logs

   mkdir -p /usr/share/elasticsearch/data/
   chown -R elasticsearch:elasticsearch /usr/share/elasticsearch/data

   # Configure elasticsearch
   # FIXME visible on localhost only
   elasticsearch_cfg=/etc/elasticsearch/elasticsearch.yml
   mv ${elasticsearch_cfg} ${elasticsearch_cfg}.orig
   cat > ${elasticsearch_cfg} <<EOF
network.host: 127.0.0.1
EOF

# Ensure is started; start also on boot.
srvc_enable elasticsearch.service
srvc_start elasticsearch
_wait_listens $ES_HOST $ES_PORT_BIN 90
_wait_listens $ES_HOST $ES_PORT_HTTP 90
}

function _install_logstash() {
   _print "- installing Logstash"

   _inst java-1.8.0-openjdk-headless
   _inst logstash

   LOGSTASH_PATTERNS_DIR=/etc/logstash/patterns
   mkdir $LOGSTASH_PATTERNS_DIR
   LOGSTASH_CONFD=/etc/logstash/conf.d

   #
   # SlipStream Java server access.
   ES_INDEX_SS=ss-access
   cat > $LOGSTASH_PATTERNS_DIR/slipstream.grok<<EOF
RESTLET_DATE %{YEAR}-%{MONTHNUM}-%{MONTHDAY}
RESTLET_URIPARAM [A-Za-z0-9$.+!*'|(){},~@#%&/=:;_?\-\[\]]*
SS_ACCESS %{RESTLET_DATE:date}\s+%{TIME:time}\s+%{IP:remote-ip}\s+%{USER:remote-user-id}\s+%{IP:server-ip}\s+%{POSINT:server-port}\s+%{WORD:method}\s+%{URIPATH:resource}\s+%{RESTLET_URIPARAM:query}\s+%{NUMBER:status}\s+%{NUMBER:bytes-sent}\s+%{NUMBER:bytes-received}\s+%{NUMBER:response-time}\s+%{URI:host-ref}
EOF

#
# Nginx access.
ES_INDEX_NGINX=nginx-access
cat > $LOGSTASH_PATTERNS_DIR/nginx.grok<<EOF
NGUSERNAME [a-zA-Z\.\@\-\+_%]+
NGUSER %{NGUSERNAME}
NGINXACCESS %{IPORHOST:clientip} %{NGUSER:ident} %{NGUSER:auth} \[%{HTTPDATE:timestamp}\] "%{WORD:verb} %{URIPATHPARAM:request} HTTP/%{NUMBER:httpversion}" %{NUMBER:response} (?:%{NUMBER:bytes}|-) (?:"(?:%{URI:referrer}|-)"|%{QS:referrer}) %{QS:agent}
EOF

cat > $LOGSTASH_CONFD/ss-nginx.conf<<EOF
input {
    beats {
        port => "$LOGSTASH_PORT"
    }
}
filter {
if [type] == "nginx-access" {
     grok {
       match => { "message" => "%{NGINXACCESS}" }
       patterns_dir => ["$LOGSTASH_PATTERNS_DIR"]
     }
  }
if [type] == "ss-access" {
     grok {
       match => { "message" => "%{SS_ACCESS}" }
       patterns_dir => ["$LOGSTASH_PATTERNS_DIR"]
     }
  }
}
output {
  if [type] == "nginx-access" {
    elasticsearch { hosts => ["$ES_HOST:9200"]
                    index => "$ES_INDEX_NGINX"
    }
  }
  if [type] == "ss-access" {
    elasticsearch { hosts => ["$ES_HOST:9200"]
                    index => "$ES_INDEX_SS"
    }
  }
}
EOF

#
# Collectd listener.
cat >$LOGSTASH_CONFD/collectd.conf<<EOF
input {
  udp {
    port => $SS_LOGSTASH_COLLECTD_UDP
    buffer_size => 1452
    codec => collectd { }
    type => "collectd"
  }
}
EOF

echo config.reload.automatic: true >> /etc/logstash/logstash.yml

srvc_enable logstash.service
srvc_start logstash
}

function _install_logging_beats() {
   _print "- installing Logstash Beats and configurations"

   _inst filebeat

   cat > /etc/filebeat/filebeat.yml<<EOF
filebeat.prospectors:
- input_type: log
  paths:
    - /var/log/nginx/access.log
  fields: 
    type: nginx-access
  fields_under_root: true
- input_type: log
  paths:
    - $SS_SERVER_LOG_DIR/slipstream.log.*
  include_lines: [".*org.restlet.engine.log.LogFilter afterHandle.*"]
  fields: 
    type: ss-access
  fields_under_root: true
tags: ["slipstream-service", "web-tier"]
output.logstash:
  hosts: ["$LOGSTASH_HOST:$LOGSTASH_PORT"]
EOF

srvc_enable filebeat.service
srvc_start filebeat
}

function _deploy_elasticstack() {
   _is_true $ES_INSTALL && _install_elasticsearch || true
}

function _deploy_nginx_proxy() {

   _print "- installing nginx and nginx configuration for SlipStream"

   # Install nginx and the configuration file for SlipStream.
   _inst nginx-1.12.2-1.el7_4.ngx
   _inst slipstream-server-nginx-conf
   srvc_start nginx
}

function _load_slipstream_examples() {
   _is_true $SS_START || return 0
   _is_true $SLIPSTREAM_EXAMPLES || return 0

   _print "- loading SlipStream examples"
   ss-login -u ${SS_USERNAME} -p ${SS_PASSWORD} --endpoint https://$SS_LOCAL_HOST
   ss-module-upload --endpoint https://$SS_LOCAL_HOST /usr/share/doc/slipstream/*.xml
}

function _upload_apikey_session_template() {
   _is_true $SS_START || srvc_start cimi
   _wait_listens $CIMI_LOCAL_HOST $CIMI_LOCAL_PORT 600
   tmpl=/tmp/api-key.json
   cat >$tmpl<<EOF
{
   "method": "api-key",
   "instance": "api-key",

   "name" : "Login with API Key and Secret",
   "description" : "Authentication with API Key and Secret",
   "group" : "Login with API Key and Secret",

   "key" : "key",
   "secret" : "secret",

   "acl": {
             "owner": {"principal": "ADMIN",
                       "type":      "ROLE"},
             "rules": [{"principal": "ADMIN",
                        "type":      "ROLE",
                        "right":     "ALL"},
                       {"principal": "ANON",
                        "type":      "ROLE",
                        "right":     "VIEW"},
                       {"principal": "USER",
                        "type":      "ROLE",
                        "right":     "VIEW"}]
          }
}
EOF
   curl -sSf -d@$tmpl -H'content-type: application/json' \
      -H'slipstream-authn-info: super ADMIN' \
      $CIMI_LOCAL_URL/api/session-template
   rm -f $tmpl
   _is_true $SS_START || srvc_stop cimi
}

##
## Deploy SlipStream one instance of job distributor and executor service
function deploy_slipstream_job_engine() {
   _print "Installing SlipStream Job distributor and executor services"
   _inst slipstream-job-engine

   cat > /etc/default/slipstream-job-distributor<<EOF
DAEMON_ARGS='--ss-url=$CIMI_LOCAL_URL --ss-user=$SS_USERNAME --ss-pass=$SS_PASSWORD --ss-insecure --zk-hosts=$ZK_ENDPOINTS'
EOF

cat > /etc/default/slipstream-job-executor<<EOF
DAEMON_ARGS='--ss-url=$CIMI_LOCAL_URL --ss-user=$SS_USERNAME --ss-pass=$SS_PASSWORD --ss-insecure --zk-hosts=$ZK_ENDPOINTS --threads=8 --es-hosts-list=$ES_HOST'
EOF

if ( _is_true $SS_START ); then
   srvc_start slipstream-job-distributor@vms_collect
   srvc_enable slipstream-job-distributor@vms_collect
   srvc_start slipstream-job-distributor@vms_cleanup
   srvc_enable slipstream-job-distributor@vms_cleanup
   srvc_start slipstream-job-distributor@jobs_cleanup
   srvc_enable slipstream-job-distributor@jobs_cleanup
   srvc_start slipstream-job-distributor@quotas_collect
   srvc_enable slipstream-job-distributor@quotas_collect
   srvc_start slipstream-job-executor
   srvc_enable slipstream-job-executor
fi
}

##
## Install Placement and Ranking service
function deploy_prs_service() {
   [ "$SS_YUM_REPO_EDITION" != "enterprise" ] && return 0
   _print "Installing Placement and Ranking service"
   _inst slipstream-pricing-server

   # Populate service attribute namespace resource.
   cat > /etc/slipstream/san.json<<EOF
{
  "prefix" : "schema-org",
  "id" : "service-attribute-namespace/schema-org",
  "acl" : {
    "owner" : {
      "principal" : "ADMIN",
      "type" : "ROLE"
    },
    "rules" : [ {
      "type" : "ROLE",
      "principal" : "ADMIN",
      "right" : "ALL"
    } ]
  },
  "resourceURI" : "http://sixsq.com/slipstream/1/ServiceAttributeNamespace",
  "uri" : "http://example.org"
}
EOF
if ( ! _is_true $SS_START ); then
   srvc_start cimi
fi
_wait_listens $CIMI_LOCAL_HOST $CIMI_LOCAL_PORT 600
curl -X POST $CIMI_LOCAL_URL/api/service-attribute-namespace \
   -H "slipstream-authn-info: super ADMIN" -H "Content-type: application/json" \
   -d@/etc/slipstream/san.json
if ( ! _is_true $SS_START ); then
   srvc_stop cimi
else
   srvc_enable ss-pricing
   srvc_start ss-pricing
fi
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
   _inst slipstream-riemann
   _install_riemann
   _add_ss_riemann_streams
   srvc_start riemann
}

function _enable_monit_jmx() {
   _print "- enabling JMX monitoring"

   java -jar $SS_SERVER_LOC/start.jar jetty.base=$SS_SERVER_LOC \
      --add-to-start=jmx-remote,jmx
   _is_true $SS_START && \
      { srvc_restart slipstream && _start_slipstream_application; } || true
}

function _install_monit_collectd() {
   _print "- installing Collectd and monitoring configurations"

   # Collectd for SlipStream JMX.
   _inst collectd-java collectd-generic-jmx
   ln -svf /usr/lib/jvm/jre/lib/amd64/server/libjvm.so /usr/lib64/libjvm.so

   branch=feature/elasticstac-installation
   gh_url=https://raw.githubusercontent.com/slipstream/SlipStream/$branch/install

   curl -sSf -o /etc/collectd.d/jmx.conf $gh_url/ss-collectd-jmx.conf
   curl -sSf -o /etc/collectd.conf $gh_url/ss-collectd.conf

   sed -i -e "s/SS_LOGSTASH_COLLECTD/$LOGSTASH_HOST/" \
      -e "s/SS_LOGSTASH_COLLECTD_UDP/$SS_LOGSTASH_COLLECTD_UDP/" \
      -e "s/SS_HOSTNAME/$SS_HOSTNAME/" /etc/collectd.conf

   ss_type_db=/usr/share/collectd/slipstream-types.db
   if [ ! -f $ss_type_db ]; then
      cat >$ss_type_db<<EOF
jmx_memory   value:GAUGE:0:U
time_ms      value:GAUGE:0:U
EOF
      cat >>/etc/collectd.conf<<EOF
TypesDB "/usr/share/collectd/types.db"
TypesDB "$ss_type_db"
EOF
   fi

   # Collectd for Nginx status.
   _inst collectd-nginx
   cat >/etc/collectd.d/nginx.conf<<EOF
LoadPlugin nginx
<Plugin nginx>
    URL "http://localhost/nginx_status"
    # User "user"
    # Password "pass"
</Plugin>
EOF

   srvc_enable collectd
   srvc_restart collectd
}

function _install_monit_metricbeat() {
   _inst metricbeat
   sed -i -e "s/hosts: \[\"localhost:9200\"\]/hosts: [\"$ES_HOST:9200\"]/" \
      /etc/metricbeat/metricbeat.yml
   srvc_enable metricbeat
   srvc_start metricbeat
}

function _install_monitoring() {
   _enable_monit_jmx
   _install_monit_collectd
   _install_monit_metricbeat
   _install_kibana
}

function _install_logging() {
   _is_true $LOGSTASH_INSTALL && _install_logstash || true
   _install_logging_beats
}

function deploy_logging_and_monitoring() {
   _print "Installing logging"
   _install_logging

   _print "Installing monitoring"
   _install_monitoring
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
deploy_slipstream_job_engine
deploy_prs_service
deploy_riemann
deploy_logging_and_monitoring
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
