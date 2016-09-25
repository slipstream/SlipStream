#!/bin/bash

set -x
set -e

#
# upgrade system
#
echo statecustom "Upgrading system..."
yum clean all
yum upgrade -y
