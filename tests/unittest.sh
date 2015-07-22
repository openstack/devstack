#!/usr/bin/env bash

# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# we always start with no errors
ERROR=0
PASS=0
FAILED_FUNCS=""

# pass a test, printing out MSG
#  usage: passed message
function passed {
    local lineno=$(caller 0 | awk '{print $1}')
    local function=$(caller 0 | awk '{print $2}')
    local msg="$1"
    if [ -z "$msg" ]; then
        msg="OK"
    fi
    PASS=$((PASS+1))
    echo "PASS: $function:L$lineno - $msg"
}

# fail a test, printing out MSG
#  usage: failed message
function failed {
    local lineno=$(caller 0 | awk '{print $1}')
    local function=$(caller 0 | awk '{print $2}')
    local msg="$1"
    FAILED_FUNCS+="$function:L$lineno\n"
    echo "ERROR: $function:L$lineno!"
    echo "   $msg"
    ERROR=$((ERROR+1))
}

# assert string comparision of val1 equal val2, printing out msg
#  usage: assert_equal val1 val2 msg
function assert_equal {
    local lineno=`caller 0 | awk '{print $1}'`
    local function=`caller 0 | awk '{print $2}'`
    local msg=$3

    if [ -z "$msg" ]; then
        msg="OK"
    fi
    if [[ "$1" != "$2" ]]; then
        FAILED_FUNCS+="$function:L$lineno\n"
        echo "ERROR: $1 != $2 in $function:L$lineno!"
        echo "  $msg"
        ERROR=$((ERROR+1))
    else
        PASS=$((PASS+1))
        echo "PASS: $function:L$lineno - $msg"
    fi
}

# assert variable is empty/blank, printing out msg
#  usage: assert_empty VAR msg
function assert_empty {
    local lineno=`caller 0 | awk '{print $1}'`
    local function=`caller 0 | awk '{print $2}'`
    local msg=$2

    if [ -z "$msg" ]; then
        msg="OK"
    fi
    if [[ ! -z ${!1} ]]; then
        FAILED_FUNCS+="$function:L$lineno\n"
        echo "ERROR: $1 not empty in $function:L$lineno!"
        echo "  $msg"
        ERROR=$((ERROR+1))
    else
        PASS=$((PASS+1))
        echo "PASS: $function:L$lineno - $msg"
    fi
}

# print a summary of passing and failing tests, exiting
# with an error if we have failed tests
#  usage: report_results
function report_results {
    echo "$PASS Tests PASSED"
    if [[ $ERROR -gt 1 ]]; then
        echo
        echo "The following $ERROR tests FAILED"
        echo -e "$FAILED_FUNCS"
        echo "---"
        exit 1
    fi
}
