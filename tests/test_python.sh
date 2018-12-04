#!/usr/bin/env bash

# Tests for DevStack INI functions

TOP=$(cd $(dirname "$0")/.. && pwd)

source $TOP/functions-common
source $TOP/inc/python

source $TOP/tests/unittest.sh

echo "Testing Python 3 functions"

# Initialize variables manipulated by functions under test.
export DISABLED_PYTHON3_PACKAGES=""

assert_true "should be enabled by default" python3_enabled_for testpackage1

assert_false "should not be disabled yet" python3_disabled_for testpackage2

disable_python3_package testpackage2
assert_equal "$DISABLED_PYTHON3_PACKAGES" "testpackage2"  "unexpected result"
assert_true "should be disabled" python3_disabled_for testpackage2

report_results
