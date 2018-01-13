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

export LC_ALL='en_US.UTF-8'

maven_goal=`ss-get maven_goal`
maven_options="`ss-get maven_options`"
nexus_creds=`ss-get nexus_creds`
slipstream_edition=`ss-get slipstream_edition`
slipstream_version=`ss-get slipstream_version`
slipstream_client_version=`ss-get slipstream_client_version`
slipstream_connectors_version=`ss-get slipstream_connectors_version`
slipstream_connectors_enterprise_version=`ss-get slipstream_connectors_enterprise_version`
slipstream_server_version=`ss-get slipstream_server_version`
slipstream_server_deps_version=`ss-get slipstream_server_deps_version`
slipstream_ui_version=`ss-get slipstream_ui_version`
slipstream_i18n_version=`ss-get slipstream_i18n_version`
slipstream_pricing_version=`ss-get slipstream_pricing_version`
skip_tests=`ss-get skip_tests`

_HOSTNAME=`ss-get hostname`

function _install_git_creds() {
    [ "$nexus_creds" == "user:pass" ] && { echo "WARNING: Skipped intallation of git credentials."; return; }

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
    chown root:root ~/.ssh/*

    echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
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
YUM_REPO_NAME=SlipStream-FromSources-$slipstream_edition

ss-set statecustom "Cloning SlipStream $slipstream_edition source code..."
if [ "$slipstream_edition" == "enterprise" ]; then
    maven_profile="-P enterprise"
else
    maven_profile="-P public"
fi
bootstrap_url=git@github.com:slipstream/SlipStreamBootstrap.git

git clone $bootstrap_url

cd SlipStreamBootstrap
mvn ${maven_profile} \
  --settings ${MAVEN_SETTINGS} \
  ${maven_options} \
  -B \
  -Dslipstream.version=${slipstream_version} \
  -Dslipstream.client.version=${slipstream_client_version} \
  -Dslipstream.connectors.version=${slipstream_connectors_version} \
  -Dslipstream.connectors.enterprise.version=${slipstream_connectors_enterprise_version} \
  -Dslipstream.server.version=${slipstream_server_version} \
  -Dslipstream.server.deps.version=${slipstream_server_deps_version} \
  -Dslipstream.ui.version=${slipstream_ui_version} \
  -Dslipstream.i18n.version=${slipstream_i18n_version} \
  -Dslipstream.pricing.version=${slipstream_pricing_version} \
  generate-sources

#
# build SlipStream
#
if [ "$slipstream_edition" == "enterprise" ]; then
    maven_options="${maven_options} -Denterprise"
fi
ss-set statecustom "Building SlipStream $slipstream_edition..."
cd SlipStream
mvn --settings ${MAVEN_SETTINGS} \
    ${maven_options} \
    -Dyum \
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
systemctl start httpd

# Open TCP:80 in the local firewall.  Insert before REJECT or append.

systemctl stop firewalld.service || true
systemctl mask firewalld.service || true
yum -y install iptables-services
systemctl start iptables.service

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

ln -sf /opt/slipstream/yum /var/www/html/
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
