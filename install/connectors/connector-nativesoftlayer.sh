#!/bin/bash

function deploy() {
    pip install importlib
    pip install SoftLayer
    yum -y install slipstream-connector-nativesoftlayer-*
}

deploy
