#!/bin/bash

set -x
set -e

curl -fsSL -o /usr/bin/boot \
   https://github.com/boot-clj/boot-bin/releases/download/latest/boot.sh
chmod 755 /usr/bin/boot

export BOOT_AS_ROOT=yes
boot -h

#
# create a settings.xml file
#
nexus_creds=`ss-get nexus_creds`
mkdir -p ~/.m2
nexus_username=`echo -n ${nexus_creds} | cut -d ':' -f 1`
nexus_password=`echo -n ${nexus_creds} | cut -d ':' -f 2`
cat > ~/.m2/settings.xml <<EOF
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                      http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <localRepository/>
  <interactiveMode/>
  <usePluginRegistry/>
  <offline/>
  <servers>
    <server>
      <id>sixsq.snapshots</id>
      <username>${nexus_username}</username>
      <password>${nexus_password}</password>
    </server>
    <server>
      <id>sixsq.releases</id>
      <username>${nexus_username}</username>
      <password>${nexus_password}</password>
    </server>
    <server>
      <id>sixsq.thirdparty</id>
      <username>${nexus_username}</username>
      <password>${nexus_password}</password>
    </server>
    <server>
      <id>slipstream.snapshots</id>
      <username>${nexus_username}</username>
      <password>${nexus_password}</password>
    </server>
    <server>
      <id>slipstream.releases</id>
      <username>${nexus_username}</username>
      <password>${nexus_password}</password>
    </server>
  </servers>
  <mirrors/>
  <proxies/>
  <profiles/>  
  <activeProfiles/>
</settings>
EOF
