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
yum install -y \
    git \
    java-1.8.0-openjdk-devel \
    python \
    python-devel \
    python-pip \
    python-mock \
    python-nose \
    python-coverage \
    python-paramiko \
    rpm-build \
    createrepo \
    npm \
    gcc
    
# Bug : https://bugzilla.redhat.com/show_bug.cgi?id=1479018
# Extracted from yum 
pip install --upgrade pip
pip install --upgrade --ignore-installed enum34 # fix bug because enum34 is already installed with yum.
pip install pylint
pip install tox

#
# install latest maven version
#
echo statecustom "Installing maven..."
maven_version=3.3.9
curl -o ~/apache-maven-${maven_version}-bin.tar.gz \
    https://www-eu.apache.org/dist/maven/maven-3/${maven_version}/binaries/apache-maven-${maven_version}-bin.tar.gz
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
# Install boot
# 
echo statecustom "Installing boot..."
boot=/usr/local/bin/boot
curl -fsSLo $boot https://github.com/boot-clj/boot-bin/releases/download/latest/boot.sh
chmod 755 $boot
ln -sf $boot /usr/bin
export BOOT_AS_ROOT=yes
$boot
cat >>~/.bashrc<<EOF
export BOOT_JVM_OPTIONS="-client -XX:+TieredCompilation -XX:TieredStopAtLevel=1 -Xmx2g -Xverify:none"
export BOOT_HOME=~/.boot
export BOOT_EMIT_TARGET=no
export BOOT_AS_ROOT=yes
EOF

#
# Install phantomjs
# 
echo statecustom "Installing phantomjs..."

# install phantomjs from SS YUM repo
curl -k -o /tmp/slipstream-repos-latest.noarch.rpm \
   https://yum.sixsq.com/slipstream-repos-latest.noarch.rpm
yum localinstall -y /tmp/slipstream-repos-latest.noarch.rpm
yum-config-manager --disable SlipStream-*
REPO_KIND=community
yum install -y --enablerepo SlipStream-Snapshots-$REPO_KIND slipstream-phantomjs

# check that the installation worked
phantomjs --version

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
