#!/usr/bin/env bash

# Tests for DevStack meta-config functions

TOP=$(cd $(dirname "$0")/.. && pwd)

# Import common functions
source $TOP/functions
source $TOP/tests/unittest.sh

function test_truefalse {
    local one=1
    local captrue=True
    local lowtrue=true
    local abrevtrue=t
    local zero=0
    local capfalse=False
    local lowfalse=false
    local abrevfalse=f
    for against in True False; do
        for name in one captrue lowtrue abrevtrue; do
            assert_equal "True" $(trueorfalse $against $name) "\$(trueorfalse $against $name)"
        done
    done
    for against in True False; do
        for name in zero capfalse lowfalse abrevfalse; do
            assert_equal "False" $(trueorfalse $against $name) "\$(trueorfalse $against $name)"
        done
    done
}

test_truefalse

report_results
