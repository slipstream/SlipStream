#!/bin/bash

function deploy() {
    yum -y install slipstream-connector-softlayer
    pip install importlib
    pip install softlayer
}

deploy
