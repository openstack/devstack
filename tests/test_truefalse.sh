#!/usr/bin/env bash

# Tests for DevStack meta-config functions

TOP=$(cd $(dirname "$0")/.. && pwd)

# Import common functions
source $TOP/functions
source $TOP/tests/unittest.sh

# common mistake is to use $FOO instead of "FOO"; in that case we
# should die
bash -c "source $TOP/functions-common; VAR=\$(trueorfalse False \$FOO)" &> /dev/null
assert_equal 1 $? "missing test-value"

VAL=$(trueorfalse False MISSING_VARIABLE)
assert_equal "False" $VAL "blank test-value"

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
            local msg="trueorfalse($default $name)"
            assert_equal "True" $(trueorfalse $default $name) "$msg"
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
            local msg="trueorfalse($default $name)"
            assert_equal "False" $(trueorfalse $default $name) "$msg"
        done
    done
}

test_trueorfalse

report_results
