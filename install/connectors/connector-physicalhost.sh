#!/bin/bash

function deploy() {
    yum -y install slipstream-connector-physicalhost
}

deploy
