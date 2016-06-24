#!/bin/bash

# input parameters
#
# deployer.ready
# ss_service_url
# connectors_to_test
# ss_users
# ss_test_user (optional - default to "test")

set -x
set -e
set -o pipefail

ss-get --timeout 2700 deployer.ready

#
# test the service
#

SS_URL=$(ss-get ss_service_url)
# space separated list
CONNECTORS_TO_TEST=$(ss-get connectors_to_test)
# u1:p1,u2:p2,..
USERPASS=$(ss-get ss_users)

USER=$(ss-get --noblock ss_test_user)
: ${USER:='test'}
PASS='tesTtesT'
for up in ${USERPASS//,/ }; do
    if [ "x${up%%:*}" == "x$USER" ]; then
       PASS=${up#*:}
       break
    fi
done

APPLICATION=examples/tutorials/service-testing/system
msg="Running deployment tests of $APPLICATION on $SS_URL as $USER:$PASS for connectors '$CONNECTORS_TO_TEST'"
ss-display "$msg"
echo $msg

for CONNECTOR in ${CONNECTORS_TO_TEST}; do
    msg="Running deployment test of $APPLICATION on $SS_URL as $USER:$PASS for connector '$CONNECTOR'"
    ss-display "$msg"
    echo $msg
    ss-execute -vvv -u $USER -p $PASS --endpoint=$SS_URL \
        -w 15 --kill-vms-on-error --keep-running never \
        --parameters "testclient:cloudservice=$CONNECTOR,apache:cloudservice=$CONNECTOR" \
        $APPLICATION 2>&1 | tee /tmp/ss-execute-$CONNECTOR.log
    rc=$?
    if [ $rc -ne 0 ]; then
        msg="ERROR: Failed '$msg'"
        ss-display "$msg"
        echo $msg
        exit $rc
    fi
done
