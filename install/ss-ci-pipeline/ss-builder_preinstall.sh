#!/bin/bash

set -x
set -e

#
# upgrade system
#
echo statecustom "Upgrading system..."
yum clean all
yum install deltarpm -y
yum upgrade -y
