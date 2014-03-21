#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#
#
# this runs a series of unit tests for devstack to ensure it's functioning

PASSES=""
FAILURES=""

# Check the return code and add the test to PASSES or FAILURES as appropriate
# pass_fail <result> <expected> <name>
function pass_fail {
    local result=$1
    local expected=$2
    local test_name=$3

    if [[ $result -ne $expected ]]; then
        FAILURES="$FAILURES $test_name"
    else
        PASSES="$PASSES $test_name"
    fi
}

if [[ -n $@ ]]; then
    FILES=$@
else
    LIBS=`find lib -type f | grep -v \.md`
    SCRIPTS=`find . -type f -name \*\.sh`
    EXTRA="functions functions-common stackrc openrc exerciserc eucarc"
    FILES="$SCRIPTS $LIBS $EXTRA"
fi

echo "Running bash8..."

./tools/bash8.py -v $FILES
pass_fail $? 0 bash8


# Test that no one is trying to land crazy refs as branches

echo "Ensuring we don't have crazy refs"

REFS=`grep BRANCH stackrc | grep -v -- '-master'`
rc=$?
pass_fail $rc 1 crazy-refs
if [[ $rc -eq 0 ]]; then
    echo "Branch defaults must be master. Found:"
    echo $REFS
fi

echo "====================================================================="
for script in $PASSES; do
    echo PASS $script
done
for script in $FAILURES; do
    echo FAILED $script
done
echo "====================================================================="

if [[ -n "$FAILURES" ]]; then
    exit 1
fi
