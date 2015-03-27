#!/bin/bash

GITHUB_URL="git@github.com:slipstream"

EDITION="Community"

LOCAL_URL="file://${WORKSPACE}/${EDITION}"

REPOS=(
"SlipStream"
"SlipStreamUI"
"SlipStreamServer"
"SlipStreamServerDeps"
"SlipStreamClient"
"SlipStreamConnectors"
# add enterprise-only repositories here -- do not remove this comment
)

TAG=NONE

# bare clone of original source repository
clone_bare_ss_repo(){
  repo=${1}

  repo_url=${GITHUB_URL}/${repo}.git
  echo "Cloning ${repo_url}"
  git clone --bare ${repo_url}
  rc=$?
  if [ ${rc} -ne 0 ]
  then
      echo "Cloning ${repo_url} failed!"
  fi

  return ${rc}
}

# clone directly from normal repositories
clone_normal_ss_repo(){
  repo=${1}

  repo_url=${GITHUB_URL}/${repo}.git
  echo "Cloning ${repo_url}"
  git clone ${repo_url}
  rc=$?
  if [ ${rc} -ne 0 ]
  then
      echo "Cloning ${repo_url} failed!"
  fi

  return ${rc}
}

# clone working copy from local repository
clone_ss_repo(){
  repo=${1}

  repo_url=${LOCAL_URL}/${repo}.git
  echo "Cloning ${repo_url}"
  git clone ${repo_url}
  rc=$?
  if [ ${rc} -ne 0 ]
  then
      echo "Cloning ${repo_url} failed!"
  fi

  return ${rc}
}

# change the SCM URLs
update_scm_urls() {
  repo=SlipStream

  sed -i "s%<scm.read>scm:git:https://github.com/slipstream%<scm.read>scm:git:file://${WORKSPACE}%" ${repo}/pom.xml
  sed -i "s%<scm.write>scm:git:ssh://git@github.com/slipstream%<scm.write>scm:git:file://${WORKSPACE}%" ${repo}/pom.xml

  (cd ${repo}; git add pom.xml; git commit -m "update scm urls"; git push)
}


# change the Nexus URL
update_nexus_urls() {
  repo=SlipStream

  sed -i "s%<nexus>http://nexus.sixsq.com/content/repositories%<nexus>file://${WORKSPACE}/repositories%g" ${repo}/pom.xml
  (cd ${repo}; git add pom.xml; git commit -m "update nexus url"; git push)
}

# Create bare copies of GitHub repositories for local testing.
# Clone those local repositories into working copies.
for repo in ${REPOS[@]}
do
    clone_normal_ss_repo ${repo}
    #clone_bare_ss_repo ${repo}
    #clone_ss_repo ${repo}
    echo
done

# Update the scm and nexus URLs to use for the following build.
# This only needs to be updated in the parent SlipStream module.
#update_scm_urls
#update_nexus_urls
