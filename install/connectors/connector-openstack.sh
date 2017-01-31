#!/bin/bash

function deploy() {
    yum -y install slipstream-connector-openstack
}

deploy
