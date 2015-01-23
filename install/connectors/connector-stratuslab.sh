#!/bin/bash

_SL_OS=centos-6
_SL_VER=v14.06.0
SL_OS_VER=${_SL_OS}-${_SL_VER}

function deploy() {

    cat > /etc/yum.repos.d/stratuslab.repo << EOF
[StratusLab-Releases]
name=StratusLab-Releases
baseurl=http://yum.stratuslab.eu/releases/${SL_OS_VER}
gpgcheck=0
EOF
    yum install -y slipstream-connector-stratuslab
}

deploy
