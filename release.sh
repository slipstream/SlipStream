#!/bin/bash

#
# Script to prepare poms for release
# Steps:
# 1- git pull the SlipStream (parent) module
# 2- update slipstream.version (remove -SNAPSHOT)
# 3- cd SlipStream (parent)
# 4- mvn clean install
# 5- push SlipStream (parent)
# 6- in Jenkins, release parent
# 7- run this script
# ...
# 8- release in Jenkins each module
# ...
# 9- git pull the SlipStream (parent) module
# 10- update slipstream.version (add -SNAPSHOT)

set -e
#set -x

# Order matters. This order will work:
modules=(SlipStreamDocumentation \
         SlipStreamServerDeps \
         SlipStreamClient \
         SlipStreamUI \
         SlipStreamServer \
         SlipStreamConnector-Abiquo \
         SlipStreamConnector-EC2 \
         SlipStreamConnector-CloudSigma \
         SlipStreamConnector-vCloud)

basedir=`pwd`

function git-pull {
    echo Calling git pull on module: $1...
    module=$1
    cd $basedir/$module
    git pull
}

function clean-install {
    echo Cleaning and installing module: $1...
    module=$1
    cd $basedir/$module
    mvn clean install
}

function release {
    echo Updating parent module on module: $1...
    module=$1
    cd $basedir/$module
    mvn versions:update-parent
    git commit -am "Update parent in preparation for release"
    git push || true
}

function post-release {
    echo Updating parent module on module: $1...
    module=$1
    cd $basedir/$module
    mvn versions:update-parent -DallowSnapshots=true
    git commit -am "Update parent after release" || true
    git push || true
}


# Let's go...

ssp_module=SlipStreamParent
echo Calling git pull on module: $ssp_module...
cd $basedir/$ssp_module
git-pull $ssp_module
echo Calling release:prepare on module: $ssp_module...
mvn release:prepare -DdryRun=true

# TODO...
# sed... change <slipstream.version>1.2.3-SNAPSHOT</slipstream.version>
#            -> <slipstream.version>1.2.3</slipstream.version>
# where the new value is the ${project.version} just updated via prepare
mvn clean install
git commit -am "Update slipstream.version and version in preparation for release" || true
git push || true

for m in "${modules[@]}"
do
    git-pull $m;
done

for m in "${modules[@]}"
do
    clean-install $m;
done

for m in "${modules[@]}"
do
    release $m;
done

cd $basedir

# TODO...
# trigger jenkins release jobs in the same order and wait for each to complete successfully
# 

for m in "${modules[@]}"
do
#    release $m;
    post-release $m;
done

