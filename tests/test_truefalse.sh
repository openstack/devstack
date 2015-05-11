#!/usr/bin/env bash

# Tests for DevStack meta-config functions

TOP=$(cd $(dirname "$0")/.. && pwd)

# Import common functions
source $TOP/functions
source $TOP/tests/unittest.sh

function test_trueorfalse {
    local one=1
    local captrue=True
    local lowtrue=true
    local uppertrue=TRUE
    local capyes=Yes
    local lowyes=yes
    local upperyes=YES

    for default in True False; do
        for name in one captrue lowtrue uppertrue capyes lowyes upperyes; do
                assert_equal "True" $(trueorfalse $default $name) "\$(trueorfalse $default $name)"
        done
    done

    local zero=0
    local capfalse=False
    local lowfalse=false
    local upperfalse=FALSE
    local capno=No
    local lowno=no
    local upperno=NO

    for default in True False; do
        for name in zero capfalse lowfalse upperfalse capno lowno upperno; do
            assert_equal "False" $(trueorfalse $default $name) "\$(trueorfalse $default $name)"
        done
    done
}

test_trueorfalse

report_results
