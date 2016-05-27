#!/bin/bash

set -x
set -e

mkdir -p $SLIPSTREAM_REPORT_DIR/ss-test-results

cp -rp ~/SlipStreamTests/clojure/target/* $SLIPSTREAM_REPORT_DIR/ss-test-results
