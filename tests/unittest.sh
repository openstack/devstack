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
FAILED_FUNCS=""

function assert_equal {
    local lineno=`caller 0 | awk '{print $1}'`
    local function=`caller 0 | awk '{print $2}'`
    local msg=$3
    if [[ "$1" != "$2" ]]; then
        FAILED_FUNCS+="$function:L$lineno\n"
        echo "ERROR: $1 != $2 in $function:L$lineno!"
        echo "  $msg"
        ERROR=1
    else
        echo "$function:L$lineno - ok"
    fi
}

function report_results {
    if [[ $ERROR -eq 1 ]]; then
        echo "Tests FAILED"
        echo $FAILED_FUNCS
        exit 1
    fi
}
