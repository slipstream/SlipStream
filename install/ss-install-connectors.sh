#!/bin/bash -ex

# Usage: <list of connector names>

CONNECTORS_URL=https://raw.githubusercontent.com/slipstream/SlipStream/master/install/connectors

echo "::: Installing connectors ${@}"
for name in "${@}"; do
    echo "   ---> ${cname}"
    script=connector-${name}.sh
    curl --fail --insecure -O ${CONNECTORS_URL}/$script || \
        { echo "Failed to get installation script for connector '${name}'"; exit 1; }
    chmod +x $script
    ./$script
done
