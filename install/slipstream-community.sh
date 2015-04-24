#!/bin/bash
set -e
set -o pipefail

REPOS=(release candidate snapshot)

declare -A REPO_TO_TAG
REPO_TO_TAG[snapshot]=master
REPO_TO_TAG[candidate]=candidate-latest
REPO_TO_TAG[release]=release-latest

declare -A REPO_TO_YUM
REPO_TO_YUM[snapshot]=Snapshots
REPO_TO_YUM[candidate]=Candidates
REPO_TO_YUM[release]=Releases

REPO=${1:-release}
if ! test "${REPO_TO_TAG[$REPO]+isset}"; then echo "Please provide one of: ${REPOS[@]}"; exit; fi

SS_INSTALL_SCRIPT=https://raw.githubusercontent.com/slipstream/SlipStream/${REPO_TO_TAG[$REPO]}/install/slipstream.sh
echo -n "::: Downlading SlipStream installation script... "
curl -sSf -k -o slipstream.sh $SS_INSTALL_SCRIPT || { echo "Failed downloading $SS_INSTALL_SCRIPT"; exit 1; }
echo "done."
chmod +x slipstream.sh

./slipstream.sh -s ${REPO_TO_YUM[$REPO]}-community

