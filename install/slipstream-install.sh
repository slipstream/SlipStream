#!/bin/bash
set -e
set -o pipefail

_SCRIPT_NAME=${0##*/}

function usage() {
    echo -e "usage:\n$_SCRIPT_NAME [edition] [repokind]
 - edition: <community|enterprise> (default: community)
 - repokind: <release|candidate|snapshot> (default: release)"
    exit 1
}

while getopts : opt; do
    case $opt in
    \?)
        usage
        ;;
    esac
done

GH_BASE_URL=https://raw.githubusercontent.com/slipstream/SlipStream

KINDS=(enterprise community)
REPOS=(release candidate snapshot)

declare -A REPO_TO_TAG
REPO_TO_TAG[snapshot]=master
REPO_TO_TAG[candidate]=candidate-latest
REPO_TO_TAG[release]=release-latest

declare -A REPO_TO_YUM
REPO_TO_YUM[snapshot]=Snapshots
REPO_TO_YUM[candidate]=Candidates
REPO_TO_YUM[release]=Releases

function _check_kind() {
    if [ "$1" != "community" ] && [ "$1" != "enterprise" ]; then
        usage
    fi
}

function _check_repo() {
    if ! test "${REPO_TO_TAG[$1]+isset}"; then
        usage
    fi
}

function _download() {
    TO=$1
    shift
    FROM=$SCRIPT_BASE_URL/$TO
    echo -n "::: Downlading $@... "
    curl -sSf -k -o $TO $FROM || { echo "Failed downloading $FROM"; exit 1; }
    echo "done."
    chmod +x $TO
}

function install_slipstream_server() {
    echo -e ":::\n::: SlipStream Service.\n:::"
    SCRIPT=slipstream.sh
    _download $SCRIPT "SlipStream installation script"
    ./$SCRIPT -s ${REPO_TO_YUM[$REPO]}-$KIND
}

function install_slipstream_connectors() {
    echo -e ":::\n::: SlipStream Cloud Connectors.\n:::"
    SCRIPT=ss-install-connectors.sh
    _download $SCRIPT "SlipStream connectors installation script"
    CONNECTORS="cloudstack occi openstack physicalhost stratuslab"
    ./$SCRIPT -r $REPO $CONNECTORS
    service slipstream restart
    echo -e "\n::: SlipStream connectors installed: $CONNECTORS"
}

KIND=${1:-community}
_check_kind $KIND
REPO=${2:-release}
_check_repo $REPO
SCRIPT_BASE_URL=$GH_BASE_URL/${REPO_TO_TAG[$REPO]}/install

install_slipstream_server
if [ "$KIND" == "community" ]; then
    install_slipstream_connectors
fi
