#!/bin/bash
set -e
set -o pipefail

_SCRIPT_NAME=${0##*/}

function usage() {
    echo -e "usage:\n$_SCRIPT_NAME [edition] [repokind]
 - edition: <community|enterprise> (default: community)
 - repokind: <release|candidate|snapshot|local> (default: release)"
    exit 1
}

while getopts : opt; do
    case $opt in
    \?)
        usage
        ;;
    esac
done

_GH_BASE_URL=https://raw.githubusercontent.com/slipstream/SlipStream

declare -A YUM_REPO_TO_GH_BRANCH
YUM_REPO_TO_GH_BRANCH[local]=master
YUM_REPO_TO_GH_BRANCH[snapshot]=master
YUM_REPO_TO_GH_BRANCH[candidate]=candidate-latest
YUM_REPO_TO_GH_BRANCH[release]=release-latest

function _check_yum_repo_kind_to_github_tag_map() {
    if ! test "${YUM_REPO_TO_GH_BRANCH[$1]+isset}"; then
        usage
    fi
}

YUM_REPO_EDITION=${1:-community}
YUM_REPO_KIND=${2:-release}
_check_yum_repo_kind_to_github_tag_map $YUM_REPO_KIND

SCRIPT_BASE_URL=$_GH_BASE_URL/${YUM_REPO_TO_GH_BRANCH[$YUM_REPO_KIND]}/install

function _download() {
    TO=$1
    shift
    FROM=$SCRIPT_BASE_URL/$TO
    echo -n "::: Downloading $@... "
    curl -sSf -k -o $TO $FROM || { echo "Failed downloading $FROM"; exit 1; }
    echo "done."
    chmod +x $TO
}

function install_slipstream_server() {
    echo -e ":::\n::: SlipStream Service.\n:::"
    SCRIPT=slipstream.sh
    _download $SCRIPT "SlipStream installation script"
    ./$SCRIPT -k $YUM_REPO_KIND -e $YUM_REPO_EDITION
}

function install_slipstream_connectors() {
    echo -e ":::\n::: SlipStream Cloud Connectors.\n:::"
    SCRIPT=ss-install-connectors.sh
    _download $SCRIPT "SlipStream connectors installation script"
    CONNECTORS="cloudstack openstack stratuslab"
    ./$SCRIPT -r $YUM_REPO_KIND $CONNECTORS
    systemctl restart slipstream restart
    echo -e "\n::: SlipStream connectors installed: $CONNECTORS"
}

install_slipstream_server
if [ "$YUM_REPO_EDITION" == "community" ]; then
    install_slipstream_connectors
fi
