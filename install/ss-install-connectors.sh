#!/bin/bash
set -e
set -o pipefail

REPO=snapshot

_SCRIPT_NAME=${0##*/}

LOG_FILE=/tmp/slipstream-connectors-install.log
exec 4>&2 3>&1 1>>${LOG_FILE} 2>&1

function _print() {
    echo -e "::: $@" 1>&3
}

function usage() {
    echo -e "usage:\n$_SCRIPT_NAME [-r repo] <list of connectors>
 -r repo: <release|candidate|snapshot> (default: release)" 1>&3
    exit 1
}

declare -A REPO_TO_TAG
REPO_TO_TAG[snapshot]=master
REPO_TO_TAG[candidate]=candidate-latest
REPO_TO_TAG[release]=release-latest

function _check_repo() {
    if ! test "${REPO_TO_TAG[$1]+isset}"; then
        usage
    fi
}

while getopts :r: opt; do
    case $opt in
    r)
        REPO=$OPTARG
        _check_repo $REPO
        ;;
    \?)
        usage
        ;;
    esac
done

shift $((OPTIND - 1)) 

GH_BASE_URL=https://raw.githubusercontent.com/slipstream/SlipStream

function _download() {
    TO=$1
    shift
    FROM=$SCRIPT_BASE_URL/$TO
    _print "Downlading $@... "
    curl -sSf -k -o $TO $FROM || { _print "ERROR: Failed downloading $FROM"; exit 1; }
    _print "done."
    chmod +x $TO
}

SCRIPT_BASE_URL=$GH_BASE_URL/${REPO_TO_TAG[$REPO]}/install/connectors

_print "Installing connectors: ${@}"
for name in "${@}"; do
    _print "   ---> ${name}"
    script=connector-${name}.sh
    _download $script "$name connector installation script"
    ./$script
done

