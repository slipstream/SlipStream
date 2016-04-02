#!/bin/bash -xe

TAG=NONE

BRANCH=${1:-master}

PUSH_CHANGES=${2:-false}

if [ "${PUSH_CHANGES}" == "true" ]; then
    TARGET=deploy
else
    TARGET=install
fi

do_push() {
    if [ "${PUSH_CHANGES}" == "true" ]; then
        echo "INFO: PUSHING changes."
        git push
    else
        echo "INFO: not pushing changes."
    fi
}

do_push_tag() {
    if [ "${PUSH_CHANGES}" == "true" ]; then
        echo "INFO: PUSHING tag ${TAG}."
        git push origin ${TAG}
    else
        echo "INFO: not pushing tag."
    fi
}

# retrieve the tag
retrieve_tag() {
  repo=SlipStream

  TAG=`grep scm.tag= ${repo}/release.properties | cut -d = -f 2`
  export TAG
}

retrieve_snapshot() {
  repo=SlipStream

  SNAPSHOT=`grep project.dev.com.sixsq.slipstream.*:SlipStream= ${repo}/release.properties | cut -d = -f 2`
  export SNAPSHOT
}

retrieve_release() {
    repo=SlipStream

      RELEASE=`grep project.rel.com.sixsq.slipstream.*:SlipStream= ${repo}/release.properties | cut -d = -f 2`
      export RELEASE
}

# update pom.xml files for tag and next development version
tag_release() {
  repo=${1}

  # make the release tag
  (cd ${repo}; find . -name pom.xml -exec cp -f {}.tag {} \; ; git add . ; git commit -m "release ${TAG}"; do_push; git tag ${TAG}; do_push_tag)

}

# update pom.xml files for tag and next development version
update_to_snapshot() {
  repo=${1}

  # update to next development version
  (cd ${repo}; find . -name pom.xml -exec cp -f {}.next {} \; ; git add . ; git commit -m "next development version"; do_push)
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
    retrieve_release
    echo "RELEASE = ${RELEASE}"

    # hack to update build.boot files
    find . -name build.boot -exec sed -i "s/^(def +version+.*)/(def +version+ \"${RELEASE}\")/" {} \;

    REPOS=`find . -type d -name SlipStream\* -a -not -name \*.git`
    for repo in ${REPOS[@]}
    do
        echo "TAGGING: ${repo}"
        tag_release ${repo}
        echo
    done
}

do_update() {
    retrieve_snapshot
    echo "SNAPSHOT = ${SNAPSHOT}"

    REPOS=`find . -type d -name SlipStream\* -a -not -name \*.git`

    # hack to update build.boot files
    find . -name build.boot -exec sed -i "s/^(def +version+.*)/(def +version+ \"${SNAPSHOT}\")/" {} \;

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
    clean ${TARGET}

#
# Enterprise Release Build
#
mvn -B \
    -Djvmargs="-Xmx1024M" \
    -DskipTests \
    -f ${WORKSPACE}/Enterprise/SlipStream/pom.xml \
    clean ${TARGET}
