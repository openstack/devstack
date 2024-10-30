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


echo "Ensuring we don't have crazy refs"

REFS=`grep BRANCH stackrc | grep -v 'TARGET_BRANCH' | grep -v 'NOVNC_BRANCH' | grep -v 'TEMPEST_BRANCH'`
rc=$?
if [[ $rc -eq 0 ]]; then
    echo "Branch defaults must be one of the *TARGET_BRANCH values. Found:"
    echo $REFS
    exit 1
fi
