#!/bin/bash
set -e
set -o pipefail

_SCRIPT_NAME=${0##*/}

function usage() {
    echo -e "usage:\n$_SCRIPT_NAME [repo]
 - repo: <release|candidate|snapshot> (default: release)"
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

declare -A REPO_TO_TAG
REPO_TO_TAG[snapshot]=master
REPO_TO_TAG[candidate]=candidate-latest
REPO_TO_TAG[release]=release-latest

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

REPO=${1:-release}
_check_repo $REPO
SCRIPT_BASE_URL=$GH_BASE_URL/${REPO_TO_TAG[$REPO]}/install

SCRIPT=slipstream-install.sh
 _download $SCRIPT "SlipStream installation wrapper script"
./$SCRIPT enterprise $REPO

