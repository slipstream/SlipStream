#!/bin/bash

set -x
set -e

#
# upgrade system
#
ss-set statecustom "Upgrading system..."
yum clean all
yum upgrade -y
