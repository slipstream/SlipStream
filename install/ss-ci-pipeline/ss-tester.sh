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
run_comp_uri=`ss-get run_comp_uri`
scale_app_uri=`ss-get scale_app_uri`
scale_comp_name=`ss-get scale_comp_name`
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
    chmod 644 ~/.ssh/config
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

cd ~

test_repo_name=SlipStreamTests

git clone git@github.com:slipstream/${test_repo_name}.git

ss-get --timeout 2700 deployer.ready

ss_serviceurl=`ss-get ss_service_url`

msg="Ready to run tests on $ss_serviceurl as $test_username."
ss-display "$msg"
echo $msg

cd $test_repo_name
git checkout $test_repo_branch

test_results_dir=~/test-results
mkdir -p $test_results_dir

_display() {
    ss-display "$1"
    echo $1
}

test_auth() {
    _display "Running authentication tests on $ss_serviceurl as $test_username."

    export BOOT_AS_ROOT=yes
    export BOOT_COLOR=no
    # We don't want to fail the deployment even if tests fail.
    make test-auth || true

    cp -rp clojure/target/* $test_results_dir
}

test_run_comp() {
    for connector in ${connectors_to_test}; do

        _display "Running simple deployment tests of $run_comp_uri on $ss_serviceurl as $test_username for connector: '$connector'"

        cat >clojure/resources/test-config.edn<<EOF
{
 :username "$test_username"
 :password "$test_userpass"
 :serviceurl "$ss_serviceurl"
 :connector-name "$connector"

 :comp-uri "$run_comp_uri"
 }
EOF

        export BOOT_AS_ROOT=yes
        export BOOT_COLOR=no
        # We don't want to fail the deployment even if tests fail.
        make test-run-comp || true

        mkdir -p $test_results_dir/$connector
        cp -rp clojure/target/* $test_results_dir/$connector
    done
}

test_run_app() {
    for connector in ${connectors_to_test}; do

        _display "Running simple deployment tests of $scale_app_uri on $ss_serviceurl as $test_username for connector: '$connector'"

        cat >clojure/resources/test-config.edn<<EOF
{
 :username "$test_username"
 :password "$test_userpass"
 :serviceurl "$ss_serviceurl"
 :connector-name "$connector"

 :app-uri "$scale_app_uri"
 }
EOF

        export BOOT_AS_ROOT=yes
        # We don't want to fail the deployment even if tests fail.
        make test-run-app || true

        mkdir -p $test_results_dir/$connector
        cp -rp clojure/target/* $test_results_dir/$connector
    done
}

test_run_app_scale() {
    for connector in ${connectors_to_test}; do

        _display "Running scalable deployment tests of $scale_app_uri on $ss_serviceurl as $test_username for connector: '$connector'"

        cat >clojure/resources/test-config.edn<<EOF
{
 :username "$test_username"
 :password "$test_userpass"
 :serviceurl "$ss_serviceurl"
 :connector-name "$connector"

 :app-uri "$scale_app_uri"
 :comp-name "$scale_comp_name"
 }
EOF

        export BOOT_AS_ROOT=yes
        export BOOT_COLOR=no
        # We don't want to fail the deployment even if tests fail.
        make test-run-app-scale || true

        mkdir -p $test_results_dir/$connector
        cp -rp clojure/target/* $test_results_dir/$connector
    done
}

# Issues of adzerk/boot-test:
# 1. Doesn't respect boot's target-path.  (--target-path PATH or -e target-path=my-path)
# 2. There is a bug in defining --junit-output-to from CLI https://github.com/adzerk-oss/boot-test/issues/24
#    TODO: `boot sift` might help.
# 3. Run single test from rom a namespace boot test -n foo.bar -f '(re-find #"my-test" (str %))': https://github.com/adzerk-oss/boot-test/issues/7

test_auth
test_run_comp
test_run_app
test_run_app_scale

_display "All tests ran."

