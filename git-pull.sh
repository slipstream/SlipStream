#!/bin/bash

GITHUB_URLS=(
"git@github.com:slipstream"
"https://github.com/slipstream"
)

REPOS=(
"SlipStreamUI"
"SlipStreamWebUI"
"SlipStreamServer"
"SlipStreamServerDeps"
"SlipStreamClient"
"SlipStreamClojureAPI"
"SlipStreamConnectors"
"SlipStreamPythonAPI"
"SlipStreamJobEngine"
"SlipStreamParent"
"SlipStreamTests"

# add enterprise-only repositories here -- do not remove this comment
"SlipStreamConnectorsEnterprise"
"SlipStreamServerEnterprise"
)

# loop over possible repository locations for cloning
clone_ss_repo(){
  repo=${1}

  for i in "${GITHUB_URLS[@]}"
  do
      repo_url=${i}/${repo}.git
      echo "Cloning ${repo_url}"
      git clone ${repo_url}
      rc=$?
      if [ ${rc} -eq 0 ]
      then
          break;
      else
          echo "Cloning ${repo_url} failed!"
      fi
  done

  return ${rc}
}

# Update or clone the given repository.
update_ss_repo(){
  repo=${1}

  rc=0
  if [ -d ${repo} ]
  then
    echo "Updating ${repo}..."
    (cd ${repo}; git rev-parse --abbrev-ref HEAD; git pull)
    rc=$?
  else
    echo "Repo ${repo} is not yet cloned here."
    clone_ss_repo ${repo}
    rc=$?
  fi

  if [ ${rc} -ne 0 ]
  then
      echo "Clone of ${repo} failed."
      exit ${rc}
  fi
}

# Loop through all requested repositories and update or clone.
for repo in ${REPOS[@]}
do
    update_ss_repo ${repo}
    echo
done
