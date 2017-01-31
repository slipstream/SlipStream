#!/bin/bash

PYPI_MINIREST_VER=0.3
PYPI_SIMPLEJSON_VER=2.6.2

function deploy() {
    # Required by CloudSigma driver
    pip-python install -Iv miniREST==$PYPI_MINIREST_VER
    pip-python install -Iv simplejson==$PYPI_SIMPLEJSON_VER
    
    yum install -y slipstream-connector-cloudsigma
}

deploy
