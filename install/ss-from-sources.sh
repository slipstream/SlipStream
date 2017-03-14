#!/bin/bash

set -x
set -e

slipstream_version=`ss-get slipstream_version`
slipstream_client_version=`ss-get slipstream_client_version`
slipstream_connectors_version=`ss-get slipstream_connectors_version`
slipstream_server_version=`ss-get slipstream_server_version`
slipstream_server_deps_version=`ss-get slipstream_server_deps_version`
slipstream_ui_version=`ss-get slipstream_ui_version`
skip_tests=`ss-get skip_tests`
install_examples=`ss-get install_examples`
slipstream_backend=`ss-get slipstream_backend`
with_refconf=`ss-get with_refconf`
NEXUS_CREDS=`ss-get nexus_creds`
REFCONF_NAME=`ss-get refconf_name`
TEST_SERVICE=`ss-get test_service`

echo "=== Parameters ===
slipstream_version = $slipstream_version
slipstream_client_version = $slipstream_client_version
slipstream_connectors_version = $slipstream_connectors_version
slipstream_server_version = $slipstream_server_version
slipstream_server_deps_version = $slipstream_server_deps_version
slipstream_ui_version = $slipstream_ui_version
skip_tests = $skip_tests
install_examples = $install_examples
slipstream_backend = $slipstream_backend
with_refconf = $with_refconf
NEXUS_CREDS = $NEXUS_CREDS
REFCONF_NAME = $REFCONF_NAME
TEST_SERVICE = $TEST_SERVICE
=== --- ==="


function _is_true() {
    if [ "x${1}" == "xtrue" ]; then
        return 0
    else
        return 1
    fi
}

#
# upgrade system
#
ss-set statecustom "Upgrading system..."
yum clean all
yum upgrade -y

#
# install dependencies
#
ss-set statecustom "Installing build dependencies..."
yum install -y epel-release yum-utils
# epel may not be enabled though
yum-config-manager --enable epel
yum clean all
yum erase -y python-paramiko python-crypto
yum install -y \
  java-1.8.0-openjdk-devel \
  python \
  python-devel \
  pylint \
  python-pip \
  python-mock \
  gcc \
  git \
  rpm-build \
  createrepo

#
# SlipStream python dependencies that require
# versions that are more recent than packages.
#
ss-set statecustom "Installing python dependencies..."
pip install nose coverage paramiko

#
# my sanity!
#
ss-set statecustom "Installing sanity..."
yum install -y emacs-nox

#
# work from home directory
#
export HOME=/root
cd ${HOME}

#
# install latest maven version
#
ss-set statecustom "Installing maven..."
maven_version=3.3.3
curl -o apache-maven-${maven_version}-bin.tar.gz \
    http://mirror.switch.ch/mirror/apache/dist/maven/maven-3/${maven_version}/binaries/apache-maven-${maven_version}-bin.tar.gz
tar zxf apache-maven-${maven_version}-bin.tar.gz

export MAVEN_HOME=~/apache-maven-${maven_version}
export MAVEN_OPTS=-Xmx2048M
export PATH=$PATH:$MAVEN_HOME/bin:${HOME}/bin

#
# install leiningen
#
ss-set statecustom "Installing leiningen..."
curl -o lein https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein
mkdir ~/bin
mv lein ~/bin
chmod a+x ~/bin/lein
export LEIN_ROOT=true
lein

#
# clone the SlipStream source code
#
ss-set statecustom "Cloning SlipStream source code..."
git clone https://github.com/slipstream/SlipStreamBootstrap

cd SlipStreamBootstrap
mvn -P public \
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
ss-set statecustom "Building SlipStream..."
cd SlipStream
mvn -B -DskipTests=${skip_tests} clean install

#
# make local yum repository
#
ss-set statecustom "Creating YUM repository..."
mkdir -p /opt/slipstream
cd /opt/slipstream
tar zxf ~/SlipStreamBootstrap/SlipStream/yum/target/SlipStream*.tar.gz
cd -

#
# installation from local repository
#
YUM_REPO_KIND=local
YUM_REPO_EDITION=community

declare -A YUM_REPO_TO_GH_BRANCH
YUM_REPO_TO_GH_BRANCH[local]=master
YUM_REPO_TO_GH_BRANCH[snapshot]=master
YUM_REPO_TO_GH_BRANCH[candidate]=candidate-latest
YUM_REPO_TO_GH_BRANCH[release]=release-latest

_GH_PROJECT_URL=https://raw.githubusercontent.com/slipstream/SlipStream
_GH_SCRIPTS_URL=$_GH_PROJECT_URL/${YUM_REPO_TO_GH_BRANCH[${YUM_REPO_KIND}]}/install
_SS_PARAM_BACKEND="-d $slipstream_backend"
if ( _is_true $with_refconf ); then
    ss-set statecustom "Installing SlipStream WITH reference configuration..."
    _NEXUS_URI=http://nexus.sixsq.com/service/local/artifact/maven/redirect
    curl -k -sSfL \
        -o /tmp/ss-install-ref-conf.sh \
        $_GH_SCRIPTS_URL/ss-install-ref-conf.sh
    chmod +x /tmp/ss-install-ref-conf.sh
    /tmp/ss-install-ref-conf.sh \
        -r $_NEXUS_URI'?r=snapshots-enterprise-rhel7&g=com.sixsq.slipstream&a=SlipStreamReferenceConfiguration-'$REFCONF_NAME'-tar&p=tar.gz&c=bundle&v=LATEST' \
        -u $NEXUS_CREDS \
        -k $YUM_REPO_KIND \
        -e $YUM_REPO_EDITION \
        -o "$_SS_PARAM_BACKEND"

    # Get and publish configured users.
    _USER_PASS=$(
    for user in /etc/slipstream/passwords/*; do
        echo -n $(basename $user):$(cat $user),;
    done)
    _USER_PASS=${_USER_PASS%,}
    ss-set ss_users $_USER_PASS

    ### Get and publish connectors to test.
    declare -A CONNECTORS
    CONNECTORS=(
        ["nuv.la"]='exoscale-ch-gva ec2-eu-west nuvlabox-james-chadwick'
        ["connectors.community"]='ultimum-cz1')

    ss-set connectors_to_test "${CONNECTORS[$REFCONF_NAME]}"
else
    ss-set statecustom "Installing SlipStream WITHOUT reference configuration..."
    export SLIPSTREAM_EXAMPLES=${install_examples}
    curl -k -sSfL \
        -o /tmp/slipstream.sh \
        $_GH_SCRIPTS_URL/slipstream.sh
    chmod +x /tmp/slipstream.sh
    /tmp/slipstream.sh $_SS_PARAM_BACKEND -e $YUM_REPO_EDITION -k $YUM_REPO_KIND
fi

#
# restarting services (probably not necessary)
systemctl restart slipstream
systemctl restart ssclj
systemctl restart nginx

#
# set the service URL
#
ss-set statecustom "SlipStream Ready!"
hostname=`ss-get hostname`
ss_url="https://${hostname}"
ss-set ss:url.service ${ss_url}

#
# validate that the installation worked
#
ss-set statecustom "Validating service..."

SS_UNAME=super
SS_UPASS=supeRsupeR
if [ -f /etc/slipstream/passwords/$SS_UNAME ]; then
    SS_UPASS=$(cat /etc/slipstream/passwords/$SS_UNAME)
fi
profile_url="${ss_url}/user/$SS_UNAME"

exit_code=0
tries=0
while [ $tries -lt 5 ]; do

  rc=`curl -k -s -u $SS_UNAME:$SS_UPASS -o /dev/null -w "%{http_code}" ${profile_url}`
  echo "Return code from $SS_UNAME profile page is " ${rc}
  if [ "${rc}" -ne "200" ]; then
    echo "Return code from $SS_UNAME profile page was not 200."
    exit_code=1
  else
    echo "Return code from $SS_UNAME profile page was 200."
    exit_code=0
    break
  fi

  sleep 10
  tries=$[$tries+1]

done
# the service failed the validation
if [ "$exit_code" -ne "0" ]; then
   exit $exit_code
fi

#
# test the service
#

if ( _is_true $TEST_SERVICE ); then
    CONNECTORS_TO_TEST=`ss-get connectors_to_test`
    msg="Running deployment tests for connectors: '${CONNECTORS_TO_TEST}'"
    ss-display "$msg"
    echo $msg
    USER=test
    for CONNECTOR in ${CONNECTORS_TO_TEST}; do
        msg="Running test on $CONNECTOR as $USER. $ss_url"
        ss-display "$msg"
        echo $msg
        ss-execute -v -u $USER -p $(cat /etc/slipstream/passwords/$USER) --endpoint=$ss_url \
            -w 15 --kill-vms-on-error \
            --parameters "testclient:cloudservice=$CONNECTOR,apache:cloudservice=$CONNECTOR" \
            examples/tutorials/service-testing/system | tee /tmp/ss-execute-$CONNECTOR.log
    done
else
    msg="Skipped running deployment tests. $ss_url"
    ss-display "$msg"
    echo $msg
fi
