#!/bin/bash

server=ci.sixsq.com
cmd=disable

usage()
{
cat <<EOF
usage: $0 options

This script enables or disables all SlipStream build jobs.

OPTIONS:
   -h      Show this message
   -e      Enable all jobs
   -d      Disable all jobs (default)
   -s      CI server (default: ci.sixsq.com)
   -u      Username
   -p      Password
EOF
}

while getopts "heds:u:p:" OPTION
do
    case $OPTION in
        h)
            usage
            exit 1
            ;;
        e)
            cmd=enable
            ;;
        d)
            cmd=disable
            ;;
        s)
            server=$OPTARG
            ;;
        u)
            username=$OPTARG
            ;;
        p)
            password=$OPTARG
            ;;
        ?)
            usage
            exit
            ;;
    esac
done

if [[ -z $server ]] || \
   [[ -z $username ]] || \
   [[ -z $password ]] || \
   [[ -z $cmd ]]
then
    usage
    exit 1
fi

jobs=(Merge_SlipStream \
      Merge_SlipStreamBootstrap \
      Merge_SlipStreamClient \
      Merge_SlipStreamConnectors \
      Merge_SlipStreamServer \
      Merge_SlipStreamServerDeps \
      Merge_SlipStreamUI \
      Community_Build \
      Enterprise_Build \
      Community_deployment_CentOS_6 \
      Community_deployment_CentOS_7 \
      Enterprise_deployment_CentOS_6 \
      SlipStream_build \
      SlipStreamClient_build \
      SlipStreamConnectors_build \
      SlipStreamServer_build \
      SlipStreamServerDeps_build \
      SlipStreamUI_build \
      SlipStream_Enterprise_build \
      SlipStreamClient_Enterprise_build \
      SlipStreamConnector-CloudSigma_build \
      SlipStreamConnector-EC2_build \
      SlipStreamConnector-NuvlaBox_build \
      SlipStreamConnector-vCloud_build \
      SlipStreamConnectors-SoftLayer_Enterprise \
      SlipStreamConnectors_Enterprise_build \
      SlipStreamI18n_build \
      SlipStreamServer_Enterprise_build \
      SlipStreamServerDeps_Enterprise_build \
      SlipStreamUI_Enterprise_build)

for job in ${jobs[@]}; do
  echo "${job}: ${cmd}d"
  curl -XPOST http://${username}:${password}@${server}/job/${job}/${cmd}
done
