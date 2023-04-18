#!/bin/bash

# basic test to ensure that package-install files remain sorted
# alphabetically.

TOP=$(cd $(dirname "$0")/.. && pwd)

source $TOP/tests/unittest.sh

export LC_ALL=en_US.UTF-8
PKG_FILES=$(find $TOP/files/debs $TOP/files/rpms -type f)

TMPDIR=$(mktemp -d)

SORTED=${TMPDIR}/sorted
UNSORTED=${TMPDIR}/unsorted

for p in $PKG_FILES; do
    grep -v '^#' $p > ${UNSORTED}
    sort ${UNSORTED} > ${SORTED}

    if [ -n "$(diff -c ${UNSORTED} ${SORTED})" ]; then
        failed "$p is unsorted"
        # output this, it's helpful to see what exactly is unsorted
        diff -c ${UNSORTED} ${SORTED}
    else
        passed "$p is sorted"
    fi
done

rm -rf ${TMPDIR}

report_results
