#!/bin/bash

function deploy() {
    yum install -y yum-priorities libxslt libxml2 libyaml dos2unix
    rpm -ivH http://repository.egi.eu/sw/production/umd/2/sl6/x86_64/updates/umd-release-2.0.0-2.el6.noarch.rpm

    #
    # The link to the ROCCI repository configuration at EGI no longer works.
    # Instead create a yum.d entry directly from the repository URL.  Note
    # that the repository URL MUST NOT end with a slash.  The EGI repository
    # does not do a redirect from the URL with the slash to the one without.
    #
    #curl -o /etc/yum.repos.d/rocci.repo http://repository.egi.eu/community/software/rocci.cli/4.2.x/releases/repofiles/sl-6-x86_64.repo
    cat > /etc/yum.repos.d/rocci.repo <<EOF
name=ROCCI CLI repository at EGI
baseurl=http://repository.egi.eu/community/software/rocci.cli/4.3.x/releases/sl/6/x86_64/RPMS
enabled=1
protect=0
gpgcheck=0
autorefresh=1
type=rpm-md

EOF

    yum -y install slipstream-connector-occi
}

deploy
