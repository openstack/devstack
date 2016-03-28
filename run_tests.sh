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

# This runs a series of unit tests for DevStack to ensure it's functioning

PASSES=""
FAILURES=""

for testfile in tests/test_*.sh; do
    $testfile
    if [[ $? -eq 0 ]]; then
        PASSES="$PASSES $testfile"
    else
        FAILURES="$FAILURES $testfile"
    fi
done

# Summary display now that all is said and done
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
