#!/bin/bash

function add_stratuslab_repo() {
    cat > /etc/yum.repos.d/stratuslab.repo <<EOF
[StratusLab-Releases]
name=StratusLab-Releases
baseurl=http://yum.stratuslab.eu/releases/centos-6-v14.06.0/
enabled=1
gpgcheck=0
EOF
}

function deploy() {
    yum -y install slipstream-connector-nuvlabox
}

add_stratuslab_repo
deploy
