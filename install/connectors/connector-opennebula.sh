#!/bin/bash

function deploy() {
    yum -y install slipstream-connector-opennebula-*
}

deploy
