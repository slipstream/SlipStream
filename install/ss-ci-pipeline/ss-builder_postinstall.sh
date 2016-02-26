#!/bin/bash

set -x
set -e

#
# install dependencies
#
echo statecustom "Installing build dependencies..."
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
echo statecustom "Installing python dependencies..."
pip install nose coverage paramiko

#
# install latest maven version
#
echo statecustom "Installing maven..."
maven_version=3.3.9
curl -o ~/apache-maven-${maven_version}-bin.tar.gz \
    http://mirror.switch.ch/mirror/apache/dist/maven/maven-3/${maven_version}/binaries/apache-maven-${maven_version}-bin.tar.gz
tar zxf ~/apache-maven-${maven_version}-bin.tar.gz -C ~
export MAVEN_HOME=~/apache-maven-${maven_version}
export MAVEN_OPTS=-Xmx2048M
export PATH=$PATH:$MAVEN_HOME/bin
cat >> ~/.bashrc << EOF
export MAVEN_HOME=~/apache-maven-${maven_version}
export MAVEN_OPTS=-Xmx2048M
export PATH=$PATH:$MAVEN_HOME/bin
EOF

#
# install leiningen
#
echo statecustom "Installing leiningen..."
mkdir -p ~/bin
curl -o ~/bin/lein https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein
chmod a+x ~/bin/lein
export PATH=$PATH:~/bin
export LEIN_ROOT=true
time lein
cat >> ~/.bashrc << EOF
export PATH=$PATH:~/bin
export LEIN_ROOT=true
EOF

#
# On some OS flavours $HOME may not be defined.
#
cat >> ~/.bashrc << EOF
export HOME=~
EOF

#
# sanity!
#
echo statecustom "Installing sanity..."
yum install -y emacs-nox vim bash-completion
