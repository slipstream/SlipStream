#!/bin/bash
set -e
set -o pipefail

_SCRIPT_NAME=${0##*/}

_YUM_REPO_KIND_DEFAULT=release

function usage() {
    echo -e "usage:\n$_SCRIPT_NAME [repokind]
 - repokind: <release|candidate|snapshot|local> (default: ${_YUM_REPO_KIND_DEFAULT})"
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

declare -A YUM_REPO_TO_GH_BRANCH
YUM_REPO_TO_GH_BRANCH[local]=master
YUM_REPO_TO_GH_BRANCH[snapshot]=master
YUM_REPO_TO_GH_BRANCH[candidate]=candidate-latest
YUM_REPO_TO_GH_TAG[${_YUM_REPO_KIND_DEFAULT}]=release-latest

function _check_repo() {
    if ! test "${YUM_REPO_TO_GH_BRANCH[$1]+isset}"; then
        usage
    fi
}

function _download() {
    TO=$1
    shift
    FROM=$SCRIPT_BASE_URL/$TO
    echo -n "::: Downloading $@... "
    curl -sSf -k -o $TO $FROM || { echo "Failed downloading $FROM"; exit 1; }
    echo "done."
    chmod +x $TO
}

YUM_REPO_KIND=${1:-${_YUM_REPO_KIND_DEFAULT}}
_check_repo $YUM_REPO_KIND
SCRIPT_BASE_URL=$GH_BASE_URL/${YUM_REPO_TO_GH_BRANCH[$YUM_REPO_KIND]}/install

SCRIPT=slipstream-install.sh
_download $SCRIPT "SlipStream installation wrapper script"
./$SCRIPT community $YUM_REPO_KIND

