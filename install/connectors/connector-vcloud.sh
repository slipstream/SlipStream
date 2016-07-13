#!/bin/bash

function deploy() {
    yum -y install slipstream-connector-vcloud-*
}

deploy
