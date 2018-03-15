#!/usr/bin/env bash

set -e
set -x

yum install -y yum-utils epel-release
yum-config-manager --enable epel
