#!/bin/bash

# input parameters
#
# deployer.ready
# ss_service_url
# connectors_to_test
# ss_users

set -x
set -e
set -o pipefail

test_repo_branch=`ss-get test_repo_branch`
scale_app_uri=`ss-get scale_app_uri`
scale_comp_name=`ss-get scale_comp_name`
ss_serviceurl=`ss-get ss_service_url`
nexus_creds=`ss-get nexus_creds`

function _install_git_creds() {

    # Get and inflate git credentials.
    TARBALL=~/git-creds.tgz
    GIT_CREDS_URL=http://nexus.sixsq.com/service/local/repositories/releases-enterprise/content/com/sixsq/slipstream/sixsq-hudson-creds/1.0.0/sixsq-hudson-creds-1.0.0.tar.gz
    SSH_DIR=~/.ssh
    mkdir -p $SSH_DIR
    chmod 0700 $SSH_DIR
    _CREDS="-u $nexus_creds"
    curl -k -L -sSf $_CREDS -o $TARBALL $GIT_CREDS_URL
    tar -C $SSH_DIR -zxvf $TARBALL
    rm -f $TARBALL
    chown root:root ~/.ssh/*

    echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
}

_install_git_creds

# space separated list
connectors_to_test=`ss-get connectors_to_test`
# u1:p1,u2:p2,..
users_passes=`ss-get ss_users`

test_username=test
test_userpass=tesTtesT
for up in ${users_passes//,/ }; do
    if [ "x${up%%:*}" == "x$test_username" ]; then
       test_userpass=${up#*:}
       break
    fi
done

cd

test_repo_name=SlipStreamTests

git clone git@github.com:slipstream/${test_repo_name}.git

ss-get --timeout 2700 deployer.ready

msg="Running deployment tests of $scale_app_uri on $ss_serviceurl as $test_username for connectors '$connectors_to_test'"
ss-display "$msg"
echo $msg

cd $test_repo_name
git checkout $test_repo_branch
for connector in ${connectors_to_test}; do
    cat >clojure/resources/test-config.edn<<EOF
{
 :username "$test_username"
 :password "$test_userpass"
 :serviceurl "$ss_serviceurl"
 :app-uri "$scale_app_uri"
 :comp-name "$scale_comp_name"
 :connector-name "$connector"
 }
EOF

    sed -i -e 's/:junit-output-to[ \t]*".*"/:junit-output-to "'${connector}'"/' \
        clojure/build.boot

    export BOOT_AS_ROOT=yes
    make clojure-test
done

msg="All tests ran successfully."
ss-display "$msg"
echo $msg

