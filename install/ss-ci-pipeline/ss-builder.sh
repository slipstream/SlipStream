#!/bin/bash

# input parameters
#
# maven_goal
# nexus_creds
# slipstream_version
# slipstream_client_version
# slipstream_connectors_version
# slipstream_server_version
# slipstream_server_deps_version
# slipstream_ui_version 
# skip_tests
# slipstream_edition (community|enterprise)

# output parameters
#
# ss-repo-conf-url
# ready

set -x
set -e


# In case configuration file is not read.
source ~/.bashrc


maven_goal=`ss-get maven_goal`
maven_options="`ss-get maven_options`"
nexus_creds=`ss-get nexus_creds`
slipstream_edition=`ss-get slipstream_edition`
slipstream_version=`ss-get slipstream_version`
slipstream_client_version=`ss-get slipstream_client_version`
slipstream_connectors_version=`ss-get slipstream_connectors_version`
slipstream_server_version=`ss-get slipstream_server_version`
slipstream_server_deps_version=`ss-get slipstream_server_deps_version`
slipstream_ui_version=`ss-get slipstream_ui_version`
skip_tests=`ss-get skip_tests`

_HOSTNAME=`ss-get hostname`

function _install_git_creds() {
    [ "$nexus_creds" -eq "user:pass" ] && { echo "WARNING: Skipped intallation of git credentials."; return; }

    # Get and inflate git credentials.
    TARBALL=~/git-creds.tgz
    GIT_CREDS_URL=http://nexus.sixsq.com/service/local/repositories/releases-enterprise/content/com/sixsq/slipstream/sixsq-hudson-creds/1.0.0/sixsq-hudson-creds-1.0.0.tar.gz
    SSH_DIR=~/.ssh
    mkdir -p $SSH_DIR
    chmod 0700 $SSH_DIR
    _CREDS="-u $nexus_creds"
    curl -k -L -sSf $_CREDS -o $TARBALL $GIT_CREDS_URL
    tar -C $SSH_DIR -zxvf $TARBALL
    rm -f $TARBALL
}

#
# work from home directory
#
cd ~

#
# get git creds for enterprise version
#
_install_git_creds

#
# create a settings.xml file (clobbering any existing file)
#
MAVEN_SETTINGS=$PWD/builder-settings.xml
nexus_username=`echo -n ${nexus_creds} | cut -d ':' -f 1`
nexus_password=`echo -n ${nexus_creds} | cut -d ':' -f 2`
cat > $MAVEN_SETTINGS <<EOF
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                      http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <localRepository/>
  <interactiveMode/>
  <usePluginRegistry/>
  <offline/>

  <servers>
    <server>
      <id>sixsq.snapshots</id>
      <username>${nexus_username}</username>
      <password>${nexus_password}</password>
    </server>
    <server>
      <id>sixsq.releases</id>
      <username>${nexus_username}</username>
      <password>${nexus_password}</password>
    </server>
    <server>
      <id>sixsq.thirdparty</id>
      <username>${nexus_username}</username>
      <password>${nexus_password}</password>
    </server>
    <server>
      <id>slipstream.snapshots</id>
      <username>${nexus_username}</username>
      <password>${nexus_password}</password>
    </server>
    <server>
      <id>slipstream.releases</id>
      <username>${nexus_username}</username>
      <password>${nexus_password}</password>
    </server>

  </servers>
  <mirrors/>
  <proxies/>
  <profiles/>  
  <activeProfiles/>

</settings>
EOF

#
# clone the SlipStream source code
#
declare -A _SS_EDITION_GH_REPO
_SS_EDITION_GH_REPO[community]=slipstream
_SS_EDITION_GH_REPO[enterprise]=SixSq

GH_REPO_EDITION=${_SS_EDITION_GH_REPO[$slipstream_edition]}
YUM_REPO_NAME=SlipStream-FromSources-$slipstream_edition

ss-set statecustom "Cloning SlipStream $slipstream_edition source code..."
# TODO: Need credentials to access private GitHub repo.
git clone https://github.com/$GH_REPO_EDITION/SlipStreamBootstrap

cd SlipStreamBootstrap
mvn -P public \
  --settings ${MAVEN_SETTINGS} \
  ${maven_options} \
  -B \
  -Dslipstream.version=${slipstream_version} \
  -Dslipstream.client.version=${slipstream_client_version} \
  -Dslipstream.connectors.version=${slipstream_connectors_version} \
  -Dslipstream.server.version=${slipstream_server_version} \
  -Dslipstream.server.deps.version=${slipstream_server_deps_version} \
  -Dslipstream.ui.version=${slipstream_ui_version} \
  generate-sources

#
# build SlipStream
#
ss-set statecustom "Building SlipStream $slipstream_edition..."
cd SlipStream
mvn --settings ${MAVEN_SETTINGS} \
    ${maven_options} \
    -B -DskipTests=${skip_tests} clean ${maven_goal}

#
# make local yum repository
#
ss-set statecustom "Creating YUM repository $YUM_REPO_NAME..."
mkdir -p /opt/slipstream
cd /opt/slipstream
tar zxf ~/SlipStreamBootstrap/SlipStream/yum/target/SlipStream*.tar.gz
cd -

#
# expose the local repo via http
#
ss-set statecustom "Exporting YUM repository $YUM_REPO_NAME..."

yum install -y httpd
service httpd start

# Open TCP:80 in the local firewall.  Insert before REJECT or append.
RULE='-m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT'
BEFORE_RULE_NUM=$(iptables -nL INPUT --line-numbers | grep REJECT | awk '{print $1}')
if [ -n "$BEFORE_RULE_NUM" ]; then
    iptables -I INPUT $BEFORE_RULE_NUM $RULE
else
    iptables -A INPUT $RULE
fi
rm -f /etc/sysconfig/iptables.bak
cp /etc/sysconfig/iptables{,.bak}
iptables-save > /etc/sysconfig/iptables

ln -s /opt/slipstream/yum /var/www/html/
cat > /var/www/html/slipstream.repo <<EOF
[$YUM_REPO_NAME]
name=$YUM_REPO_NAME
baseurl=http://${_HOSTNAME}/yum
enabled=1
protect=0
gpgcheck=0
metadata_expire=30s
autorefresh=1
type=rpm-md
sslverify=0
EOF

ss-set ss-repo-conf-url "http://${_HOSTNAME}/slipstream.repo"
ss-set ss:url.service "http://${_HOSTNAME}/yum"

ss-set ready true
