#!/bin/bash

set -x
set -e

curl -fsSL -o /usr/bin/lein \
   https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein
chmod 755 /usr/bin/lein

export LEIN_ROOT=true
lein -h
