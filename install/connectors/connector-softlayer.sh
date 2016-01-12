#!/bin/bash

function deploy() {
    yum -y install slipstream-connector-softlayer
    pip install softlayer
}

deploy
