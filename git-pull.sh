#!/bin/bash

update_ss_repo(){
  if [ -d ${1} ]
  then
    echo "Updating ${1}..."
    (cd ${1}; git pull)
  else
    echo "Repo ${1} is not yet cloned here."
    echo "Cloning ${1}..."
    git clone git@github.com:slipstream/${1}.git
  fi
  echo
}

update_ss_repo "SlipStream"
update_ss_repo "SlipStreamDocumentation"
update_ss_repo "SlipStreamUI"
update_ss_repo "SlipStreamServer"
update_ss_repo "SlipStreamServerDeps"
update_ss_repo "SlipStreamClient"
update_ss_repo "SlipStreamConnectors"
