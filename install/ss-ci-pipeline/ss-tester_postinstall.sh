#!/bin/bash

set -x
set -e

curl -fsSL -o /usr/bin/boot \
   https://github.com/boot-clj/boot-bin/releases/download/latest/boot.sh
chmod 755 /usr/bin/boot

export BOOT_AS_ROOT=yes
boot -h
