#!/bin/bash

set -x
set -e

mkdir -p $SLIPSTREAM_REPORT_DIR/ss-test-results

[ -d ~/SlipStreamTests/clojure/target ] && \
   cp -rp ~/SlipStreamTests/clojure/target/* $SLIPSTREAM_REPORT_DIR/ss-test-results
