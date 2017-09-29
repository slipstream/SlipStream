#!/bin/bash

# input parameteres
#
# install_examples
# slipstream_backend
# with_refconf
# nexus_creds
# refconf_name
# yum_repo_kind
# yum_repo_edition
# ss-repo-conf-url
# builder.ready

# output parameteres
#
# ss_service_url
# connectors_to_test
# ss_users
# ready

set -x
set -e

function _is_true() {
    if [ "x${1}" == "xtrue" ]; then
        return 0
    else
        return 1
    fi
}

function _is_none() {
    if [ "x${1}" == "xNone" ]; then
        return 0
    else
        return 1
    fi
}

yum clean all
yum upgrade -y

ss-get --timeout 3600 builder.ready

install_examples=`ss-get install_examples`
slipstream_backend=`ss-get slipstream_backend`
with_refconf=`ss-get with_refconf`
NEXUS_CREDS=`ss-get nexus_creds`
REFCONF_NAME=`ss-get refconf_name`
YUM_REPO_KIND=`ss-get yum_repo_kind`
YUM_REPO_EDITION=`ss-get yum_repo_edition`
SS_REPO_CONF_URL=`ss-get ss-repo-conf-url`
install_scripts_branch=`ss-get install_scripts_branch`
ES_HOST_PORT=`ss-get es-host-port`

function _install_yum_client_cert() {
    SS_CONF_DIR=/etc/slipstream
    mkdir -p $SS_CONF_DIR

    TARBALL=~/yum-certs.tgz
    _CREDS=
    if [ -n "$NEXUS_CREDS" ]; then
        _CREDS="-u $NEXUS_CREDS"
    fi
    curl -k -L -sSf $_CREDS -o $TARBALL $1
    tar -C $SS_CONF_DIR -zxvf $TARBALL
    chmod 400 $SS_CONF_DIR/yum-client.*
    rm -f $TARBALL
}

#
# for installation from local repository
#

declare -A YUM_REPO_TO_GH_BRANCH
YUM_REPO_TO_GH_BRANCH[local]=master
YUM_REPO_TO_GH_BRANCH[snapshot]=master
YUM_REPO_TO_GH_BRANCH[candidate]=candidate-latest
YUM_REPO_TO_GH_BRANCH[release]=release-latest

_GH_PROJECT_URL=https://raw.githubusercontent.com/slipstream/SlipStream
if [ "$install_scripts_branch" != "master" ]; then
    GH_BRANCH=$install_scripts_branch
else
    GH_BRANCH=${YUM_REPO_TO_GH_BRANCH[${YUM_REPO_KIND}]}
fi
_GH_SCRIPTS_URL=$_GH_PROJECT_URL/$GH_BRANCH/install
SS_PARAM_BACKEND="-d $slipstream_backend -a $ES_HOST_PORT"
_NEXUS_URI=http://nexus.sixsq.com/service/local/artifact/maven/redirect
if ( _is_true $with_refconf ); then
    ss-set statecustom "Installing SlipStream WITH reference configuration..."
    curl -k -sSfL \
        -o /tmp/ss-install-ref-conf.sh \
        $_GH_SCRIPTS_URL/ss-install-ref-conf.sh
    chmod +x /tmp/ss-install-ref-conf.sh
    REF_CONF_URL=$_NEXUS_URI'?r=snapshots-enterprise-rhel7&g=com.sixsq.slipstream&a=SlipStreamReferenceConfiguration-'$REFCONF_NAME'-tar&p=tar.gz&c=bundle&v=LATEST'
    ref_conf_params="-r $REF_CONF_URL -u $NEXUS_CREDS -e $YUM_REPO_EDITION -b $GH_BRANCH"
    if ( _is_none ${SS_REPO_CONF_URL} ); then
        if [ "X$YUM_REPO_EDITION" == "Xenterprise" ]; then
            /tmp/ss-install-ref-conf.sh \
                $ref_conf_params \
                -k $YUM_REPO_KIND \
                -c ${_NEXUS_URI}'?r=releases-enterprise&g=com.sixsq.slipstream&a=SlipStreamYUMCertsForSlipStreamInstaller&p=tgz&v=LATEST' \
                -p $NEXUS_CREDS \
                -o "$SS_PARAM_BACKEND"
        else
            /tmp/ss-install-ref-conf.sh \
                $ref_conf_params \
                -o "$SS_PARAM_BACKEND"
        fi
    else
        /tmp/ss-install-ref-conf.sh \
            $ref_conf_params \
            -o "$SS_PARAM_BACKEND -x $SS_REPO_CONF_URL"
    fi

    # Get and publish configured users.
    _USER_PASS=$(
    for user in /etc/slipstream/passwords/*; do
        echo -n $(basename $user):$(cat $user),;
    done)
    _USER_PASS=${_USER_PASS%,}
    ss-set ss_users $_USER_PASS

    ### Get and publish connectors to test.
    declare -A CONNECTORS
    CONNECTORS=(
        ["nuv.la"]='exoscale-ch-gva ec2-eu-west'
        ["connectors.community"]='ultimum-cz1')

    ss-set connectors_to_test "${CONNECTORS[$REFCONF_NAME]}"
else
    ss-set statecustom "Installing SlipStream WITHOUT reference configuration..."
    export SLIPSTREAM_EXAMPLES=${install_examples}
    curl -k -sSfL \
        -o /tmp/slipstream.sh \
        $_GH_SCRIPTS_URL/slipstream.sh
    chmod +x /tmp/slipstream.sh
    if [ "X$YUM_REPO_EDITION" == "Xenterprise" ]; then
        _install_yum_client_cert \
            ${_NEXUS_URI}'?r=releases-enterprise&g=com.sixsq.slipstream&a=SlipStreamYUMCertsForSlipStreamInstaller&p=tgz&v=LATEST'
    fi
    if ( _is_none ${SS_REPO_CONF_URL} ); then
        /tmp/slipstream.sh $SS_PARAM_BACKEND -a $ES_HOST_PORT -e $YUM_REPO_EDITION -k $YUM_REPO_KIND
    else
        /tmp/slipstream.sh $SS_PARAM_BACKEND -a $ES_HOST_PORT -x $SS_REPO_CONF_URL
    fi
fi

#
# Reduce the memory consumption of ElasticSearch
#
if [ "X$ES_HOST_PORT" == "Xlocalhost:9300" ]; then
    sed -i 's/^-Xms.*/-Xms256m/' /etc/elasticsearch/jvm.options
    sed -i 's/^-Xmx.*/-Xmx1g/' /etc/elasticsearch/jvm.options
    systemctl restart elasticsearch
fi

#
# restarting services (probably not necessary)
systemctl restart slipstream
systemctl restart ssclj
systemctl restart nginx

#
# set the service URL
#
ss-set statecustom "SlipStream Ready!"
hostname=`ss-get hostname`
ss_url="https://${hostname}"
ss-set ss:url.service ${ss_url}
ss-set ss_service_url ${ss_url}

#
# validate that the installation worked
#
ss-set statecustom "Validating service..."

SS_UNAME=super
SS_UPASS=supeRsupeR
if [ -f /etc/slipstream/passwords/$SS_UNAME ]; then
    SS_UPASS=$(cat /etc/slipstream/passwords/$SS_UNAME)
fi
profile_url="${ss_url}/user/$SS_UNAME"

exit_code=0
tries=0
while [ $tries -lt 5 ]; do

  rc=`curl -k -s -u $SS_UNAME:$SS_UPASS -o /dev/null -w "%{http_code}" ${profile_url}`
  echo "Return code from $SS_UNAME profile page is " ${rc}
  if [ "${rc}" -ne "200" ]; then
    echo "Return code from $SS_UNAME profile page was not 200."
    exit_code=1
  else
    echo "Return code from $SS_UNAME profile page was 200."
    exit_code=0
    break
  fi

  sleep 10
  tries=$[$tries+1]

done
# the service failed the validation
if [ "$exit_code" -ne "0" ]; then
   ss-set statecustom "ERROR: Service failed validation."
   exit $exit_code
fi

ss-set statecustom "Service deployed and validated."
ss-set ready true
