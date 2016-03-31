#!/bin/bash

TAG=NONE

BRANCH=${1:-master}

# retrieve the tag
retrieve_tag() {
  repo=SlipStream

  TAG=`grep scm.tag= ${repo}/release.properties | cut -d = -f 2`
  export TAG
}

# update pom.xml files for tag and next development version
tag_release() {
  repo=${1}

  # make the release tag
  (cd ${repo}; find . -name pom.xml -exec mv -f {}.tag {} \; ; mvn generate-sources -DupdateBootVersion ; git add . ; git commit -m "release ${TAG}"; git push; git tag ${TAG}; git push origin ${TAG})

}

# update pom.xml files for tag and next development version
update_to_snapshot() {
  repo=${1}

  # update to next development version
  (cd ${repo}; find . -name pom.xml -exec mv -f {}.next {} \; ; mvn generate-sources -DupdateBootVersion; git add . ; git commit -m "next development version"; git push)
}

# checkout given version (tag or master)
checkout() {
  repo=${1}
  tag=${2}

  (cd ${repo}; git checkout ${tag})
}

do_tag() {
    retrieve_tag
    echo "TAG = ${TAG}"

    REPOS=`find . -type d -name SlipStream\* -a -not -name \*.git`
    for repo in ${REPOS[@]}
    do
        echo "TAGGING: ${repo}"
        tag_release ${repo}
        echo
    done
}

do_update() {
    REPOS=`find . -type d -name SlipStream\* -a -not -name \*.git`
    for repo in ${REPOS[@]}
    do
        echo "UPDATING: ${repo}"
        update_to_snapshot ${repo}
        echo
    done
}

do_checkout() {
    retrieve_tag
    echo "TAG = ${TAG}"

    REPOS=`find . -type d -name SlipStream\* -a -not -name \*.git`
    for repo in ${REPOS[@]}
    do
        echo "CHECKOUT: ${repo}"
        checkout ${repo} ${TAG}
        echo
    done
}

cd ${WORKSPACE}
git clone git@github.com:slipstream/SlipStreamBootstrap.git Community

cd ${WORKSPACE}/Community
mvn generate-sources -Dslipstream.version.default=${BRANCH}

cd ${WORKSPACE}
git clone git@github.com:SixSq/SlipStreamBootstrap.git Enterprise

cd ${WORKSPACE}/Enterprise
mvn generate-sources -Dslipstream.version.default=${BRANCH}

cd ${WORKSPACE}

mvn -Djvmargs="-Xmx1024M" \
    -DdryRun \
    -f ${WORKSPACE}/Community/SlipStream/pom.xml \
    -B \
    -DskipTests \
    release:prepare

mvn -Djvmargs="-Xmx1024M" \
    -DdryRun \
    -f ${WORKSPACE}/Enterprise/SlipStream/pom.xml \
    -B \
    -DskipTests \
    release:prepare

#
# Community Tag
#
(cd ${WORKSPACE}/Community; do_tag)

#
# Enterprise Tag
#
(cd ${WORKSPACE}/Enterprise; do_tag)

#
# Community Update to Snapshot
#
(cd ${WORKSPACE}/Community; do_update)

#
# Enterprise Update to Snapshot
#
(cd ${WORKSPACE}/Enterprise; do_update)

#
# Community Checkout
#
(cd ${WORKSPACE}/Community; do_checkout)

#
# Enterprise Checkout
#
(cd ${WORKSPACE}/Enterprise; do_checkout)

#
# Community Release Build
#
mvn -B \
    -Djvmargs="-Xmx1024M" \
    -DskipTests \
    -f ${WORKSPACE}/Community/SlipStream/pom.xml \
    clean deploy

#
# Enterprise Release Build
#
mvn -B \
    -Djvmargs="-Xmx1024M" \
    -DskipTests \
    -f ${WORKSPACE}/Enterprise/SlipStream/pom.xml \
    clean deploy
