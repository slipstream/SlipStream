#!/bin/bash

function deploy() {
    yum -y install slipstream-connector-softlayer
}

deploy
