#!/bin/bash

function deploy() {
    yum install -y yum-priorities libxslt libxml2 libyaml dos2unix
    rpm -ivH http://repository.egi.eu/sw/production/umd/2/sl6/x86_64/updates/umd-release-2.0.0-2.el6.noarch.rpm
    wget -O /etc/yum.repos.d/rocci.repo http://repository.egi.eu/community/software/rocci.cli/4.2.x/releases/repofiles/sl-6-x86_64.repo

    yum -y install slipstream-connector-occi
}

deploy