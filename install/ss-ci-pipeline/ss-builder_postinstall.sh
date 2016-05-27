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
    pylint \
    python-mock \
    python-nose \
    python-coverage \
    python-paramiko \
    rpm-build \
    createrepo

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
# Install boot
# 
echo statecustom "Installing boot..."
boot=/usr/local/bin/boot
curl -fsSLo $boot https://github.com/boot-clj/boot-bin/releases/download/latest/boot.sh
chmod 755 $boot
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

# install dependencies
yum install -y bzip2 fontconfig freetype libstdc++

# copy and install the binary
phantomjs=/usr/local/bin/phantomjs
phantomjs_dir=phantomjs-2.1.1-linux-x86_64
phantomjs_bz2=${phantomjs_dir}.tar.bz2
phantomjs_url=https://bitbucket.org/ariya/phantomjs/downloads/
curl -fsSLov /tmp/${phantomjs_bz2} ${phantomjs_url}${phantomjs_bz2}
tar jxf /tmp/${phantomjs_bz2} -C /tmp
cp /tmp/${phantomjs_dir}/bin/phantomjs ${phantomjs}
chmod 755 ${phantomjs}

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
