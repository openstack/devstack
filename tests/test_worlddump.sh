#!/bin/bash

# Simple test of worlddump.py

TOP=$(cd $(dirname "$0")/.. && pwd)

source $TOP/tests/unittest.sh

OUT_DIR=$(mktemp -d)

${PYTHON} $TOP/tools/worlddump.py -d $OUT_DIR

if [[ $? -ne 0 ]]; then
    fail "worlddump failed"
else

    # worlddump creates just one output file
    OUT_FILE=($OUT_DIR/*.txt)

    if [ ! -r $OUT_FILE ]; then
        failed "worlddump output not seen"
    else
        passed "worlddump output $OUT_FILE"

        if [[ $(stat -c %s $OUT_DIR/*.txt) -gt 0 ]]; then
            passed "worlddump output is not zero sized"
        fi

        # put more extensive examination here, if required.
    fi
fi

rm -rf $OUT_DIR

report_results
