#!/bin/bash -x

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
# quick installation from local repository
#
ss-set statecustom "Installing SlipStream..."
export SLIPSTREAM_EXAMPLES=${install_examples}
curl -sSfL -o /tmp/slipstream.sh \
    https://raw.githubusercontent.com/slipstream/SlipStream/master/install/slipstream.sh
chmod +x /tmp/slipstream.sh
/tmp/slipstream.sh -d $slipstream_backend -e community -k local

#
# restarting services (probably not necessary)
service slipstream restart
service ssclj restart
service nginx restart

#
# set the service URL
#
ss-set statecustom "SlipStream Ready!"
hostname=`ss-get hostname`
url="https://${hostname}"
ss-set ss:url.service ${url}

#
# validate that the installation worked
#
ss-set statecustom "Validating service..."
exit_code=0

profile_url="${url}/user/super"

tries=0
while [ $tries -lt 5 ]; do

  rc=`curl -k -s -u super:supeRsupeR -o /dev/null -w "%{http_code}" ${profile_url}`
  echo "Return code from super profile page is " ${rc}
  if [ "${rc}" -ne "200" ]; then
    echo "Return code from super profile page was not 200."
    exit_code=1
  else
    echo "Return code from super profile page was 200."
    exit_code=0
    exit $exit_code
  fi

  sleep 10
  tries=$[$tries+1]

done

exit $exit_code

