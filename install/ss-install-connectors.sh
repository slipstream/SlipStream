#!/bin/bash -ex

# Usage: <list of connector names>

CONNECTORS_URL=https://raw.githubusercontent.com/slipstream/SlipStream/master/install/connectors

echo "::: Installing connectors ${@}"
for name in "${@}"; do
    echo "   ---> ${cname}"
    script=connector-${name}.sh
    curl -k -O ${CONNECTORS_URL}/$script
    chmod +x $script
    ./$script
done
