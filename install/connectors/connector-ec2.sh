#!/bin/bash

function deploy() {
    # EPEL repo is required. slipstream-connector-ec2 depends on
    # slipstream-connector-ec2-python, which requires python-boto,
    # which in turn comes from EPEL.
    yum install -y --enablerepo=epel slipstream-connector-ec2
}

deploy
