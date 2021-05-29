#!/usr/bin/env bash

TOP=$(cd $(dirname "$0")/.. && pwd)

# Import common functions
source $TOP/functions
source $TOP/tests/unittest.sh

${PYTHON} $TOP/roles/write-devstack-local-conf/library/test.py
