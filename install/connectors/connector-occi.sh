#!/bin/bash

rOCCI_VERSION=4.2.x
UMD_VERSION=3.0.1-1

function deploy() {
    yum install -y yum-priorities libxslt libxml2 libyaml dos2unix
    rpm -ivH http://repository.egi.eu/sw/production/umd/${UMD_VERSION%%.*}/sl6/x86_64/updates/umd-release-${UMD_VERSION}.el6.noarch.rpm

    #
    # The link to the ROCCI repository at EGI is unstable.  In addition,
    # the actual RPM repository sometimes returns a 404 error, so working
    # around the instability of the repository isn't reliable.
    #
    curl -o /etc/yum.repos.d/rocci.repo http://repository.egi.eu/community/software/rocci.cli/${rOCCI_VERSION}/releases/repofiles/sl-6-x86_64.repo

    yum -y install slipstream-connector-occi
}

deploy
