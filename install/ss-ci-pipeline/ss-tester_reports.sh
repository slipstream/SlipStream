#!/bin/bash

set -x
set -e

test_results_dir=~/test-results

[ -d $test_results_dir ] && cp -rp $test_results_dir $SLIPSTREAM_REPORT_DIR
