#!/usr/bin/env bash

# Tests for DevStack INI functions

TOP=$(cd $(dirname "$0")/.. && pwd)

source $TOP/functions-common
source $TOP/inc/python

source $TOP/tests/unittest.sh

echo "Testing Python 3 functions"

# Initialize variables manipulated by functions under test.
export ENABLED_PYTHON3_PACKAGES=""
export DISABLED_PYTHON3_PACKAGES=""

assert_false "should not be enabled yet" python3_enabled_for testpackage1

enable_python3_package testpackage1
assert_equal "$ENABLED_PYTHON3_PACKAGES" "testpackage1"  "unexpected result"
assert_true "should be enabled" python3_enabled_for testpackage1

assert_false "should not be disabled yet" python3_disabled_for testpackage2

disable_python3_package testpackage2
assert_equal "$DISABLED_PYTHON3_PACKAGES" "testpackage2"  "unexpected result"
assert_true "should be disabled" python3_disabled_for testpackage2

report_results
