#!/bin/bash

set -x
set -e

# Hack due to an issue in aleph via kvlt.
yum remove -y java-1.8.0-openjdk-headless
yum localinstall -y http://yum.sixsq.com/thirdparty/jdk-8u91-linux-x64.rpm

curl -fsSL -o /usr/bin/boot \
   https://github.com/boot-clj/boot-bin/releases/download/latest/boot.sh
chmod 755 /usr/bin/boot

export BOOT_AS_ROOT=yes
boot -h
