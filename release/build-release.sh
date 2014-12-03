#!/bin/bash

REPOS=(
"SlipStream"
"SlipStreamDocumentation"
"SlipStreamUI"
"SlipStreamServer"
"SlipStreamServerDeps"
"SlipStreamClient"
"SlipStreamConnectors"
# add enterprise-only repositories here -- do not remove this comment
)

TAG=NONE

# retrieve the tag
retrieve_tag() {
  repo=SlipStream

  TAG=`grep scm.tag= ${repo}/release.properties | cut -d = -f 2`
  export TAG
}

# update pom.xml files for tag and next development version
tag_and_update() {
  repo=${1}

  # make the release tag
  (cd ${repo}; find . -name pom.xml -exec mv -f {}.tag {} \; ; git add . ; git commit -m "release ${TAG}"; git push; git tag ${TAG}; git push origin ${TAG})

  # update to next development version
  (cd ${repo}; find . -name pom.xml -exec mv -f {}.next {} \; ; git add . ; git commit -m "next development version"; git push)
}

# checkout given version (tag or master)
checkout() {
  repo=${1}
  tag=${2}

  (cd ${repo}; git checkout ${tag})
}

# Get the tag
retrieve_tag
echo "TAG = ${TAG}"

# Push release pom.xml files into repository; check out tag.
for repo in ${REPOS[@]}
do
    tag_and_update ${repo}
    checkout ${repo} ${TAG}
    echo
done
