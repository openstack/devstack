#!/usr/bin/env bash

# Tests for DevStack INI functions

TOP=$(cd $(dirname "$0")/.. && pwd)

# Import config functions
source $TOP/inc/ini-config

source $TOP/tests/unittest.sh

set -e

echo "Testing INI functions"

INI_TMP_DIR=$(mktemp -d)
INI_TMP_ETC_DIR=$INI_TMP_DIR/etc
TEST_INI=${INI_TMP_ETC_DIR}/test.ini
mkdir ${INI_TMP_ETC_DIR}

echo "Creating $TEST_INI"
cat >${TEST_INI} <<EOF
[default]
# comment an option
#log_file=./log.conf
log_file=/etc/log.conf
handlers=do not disturb

[aaa]
# the commented option should not change
#handlers=cc,dd
handlers = aa, bb

[bbb]
handlers=ee,ff

[ ccc ]
spaces  =  yes

[ddd]
empty =

[eee]
multi = foo1
multi = foo2

[key_with_spaces]
rgw special key = something

# inidelete(a)
[del_separate_options]
a=b
b=c

# inidelete(a)
[del_same_option]
a=b
a=c

# inidelete(a)
[del_missing_option]
b=c

# inidelete(a)
[del_missing_option_multi]
b=c
b=d

# inidelete(a)
[del_no_options]

# inidelete(a)
# no section - del_no_section

EOF

# set TEST_SUDO to test writing to root-owned files
SUDO_ARG=""
SUDO=""
if [ -n "$TEST_SUDO" ]; then
    SUDO="sudo "
    SUDO_ARG="-sudo "
    sudo chown -R root:root ${INI_TMP_ETC_DIR}
fi

# test iniget_sections
VAL=$(iniget_sections "${TEST_INI}")
assert_equal "$VAL" "default aaa bbb ccc ddd eee key_with_spaces \
del_separate_options del_same_option del_missing_option \
del_missing_option_multi del_no_options"

# Test with missing arguments
BEFORE=$(cat ${TEST_INI})

iniset ${SUDO_ARG} ${TEST_INI} aaa
NO_ATTRIBUTE=$(cat ${TEST_INI})
assert_equal "$BEFORE" "$NO_ATTRIBUTE" "test missing attribute argument"

iniset ${SUDO_ARG} ${TEST_INI}
NO_SECTION=$(cat ${TEST_INI})
assert_equal "$BEFORE" "$NO_SECTION" "missing section argument"

# Test with spaces in values
VAL=$(iniget ${TEST_INI} aaa handlers)
assert_equal "$VAL" "aa, bb" "iniget spaces in option"

iniset ${SUDO_ARG} ${TEST_INI} aaa handlers "11, 22"
VAL=$(iniget ${TEST_INI} aaa handlers)
assert_equal "$VAL" "11, 22" "iniset spaces in option"

# Test with spaces in section header
VAL=$(iniget ${TEST_INI} " ccc " spaces)
assert_equal "$VAL" "yes" "iniget with section header space"

iniset ${SUDO_ARG} ${TEST_INI} "b b" opt_ion 42
VAL=$(iniget ${TEST_INI} "b b" opt_ion)
assert_equal "$VAL" "42" "iniset with section header space"

# Test without spaces, end of file
VAL=$(iniget ${TEST_INI} bbb handlers)
assert_equal "$VAL" "ee,ff" "iniget at EOF"

iniset ${SUDO_ARG} ${TEST_INI} bbb handlers "33,44"
VAL=$(iniget ${TEST_INI} bbb handlers)
assert_equal "$VAL" "33,44" "inset at EOF"

# test empty option
if ini_has_option ${TEST_INI} ddd empty; then
    passed "ini_has_option: ddd.empty present"
else
    failed "ini_has_option failed: ddd.empty not found"
fi

# test non-empty option
if ini_has_option ${TEST_INI} bbb handlers; then
    passed "ini_has_option: bbb.handlers present"
else
    failed "ini_has_option failed: bbb.handlers not found"
fi

# test changing empty option
iniset ${SUDO_ARG} ${TEST_INI} ddd empty "42"
VAL=$(iniget ${TEST_INI} ddd empty)
assert_equal "$VAL" "42" "change empty option"

# test pipe in option
iniset ${SUDO_ARG} ${TEST_INI} aaa handlers "a|b"
VAL=$(iniget ${TEST_INI} aaa handlers)
assert_equal "$VAL" "a|b" "pipe in option"

# Test section not exist
VAL=$(iniget ${TEST_INI} zzz handlers)
assert_empty VAL "section does not exist"

# Test option not exist
VAL=$(iniget ${TEST_INI} aaa debug)
assert_empty VAL "option does not exist"

if ! ini_has_option ${TEST_INI} aaa debug; then
    passed "ini_has_option: aaa.debug not present"
else
    failed "ini_has_option failed: aaa.debug"
fi

# Test comments
inicomment ${SUDO_ARG} ${TEST_INI} aaa handlers
VAL=$(iniget ${TEST_INI} aaa handlers)
assert_empty VAL "test inicomment"

# Test multiple line iniset/iniget
iniset_multiline ${SUDO_ARG} ${TEST_INI} eee multi bar1 bar2

VAL=$(iniget_multiline ${TEST_INI} eee multi)
assert_equal "$VAL" "bar1 bar2" "iniget_multiline"

# Test iniadd with exiting values
iniadd ${SUDO_ARG} ${TEST_INI} eee multi bar3
VAL=$(iniget_multiline ${TEST_INI} eee multi)
assert_equal "$VAL" "bar1 bar2 bar3" "iniadd with existing values"

# Test iniadd with non-exiting values
iniadd ${SUDO_ARG} ${TEST_INI} eee non-multi foobar1 foobar2
VAL=$(iniget_multiline ${TEST_INI} eee non-multi)
assert_equal "$VAL" "foobar1 foobar2" "iniadd non-existing values"

# Test inidelete
del_cases="
    del_separate_options
    del_same_option
    del_missing_option
    del_missing_option_multi
    del_no_options
    del_no_section"

for x in $del_cases; do
    inidelete ${SUDO_ARG} ${TEST_INI} $x a
    VAL=$(iniget_multiline ${TEST_INI} $x a)
    assert_empty VAL "inidelete $x"
    if [ "$x" = "del_separate_options" -o \
        "$x" = "del_missing_option" -o \
        "$x" = "del_missing_option_multi" ]; then
        VAL=$(iniget_multiline ${TEST_INI} $x b)
        if [ "$VAL" = "c" -o "$VAL" = "c d" ]; then
            passed "inidelete other_options $x"
        else
            failed "inidelete other_option $x: $VAL"
        fi
    fi
done

# test file-creation
iniset $SUDO_ARG ${INI_TMP_ETC_DIR}/test.new.ini test foo bar
VAL=$(iniget ${INI_TMP_ETC_DIR}/test.new.ini test foo)
assert_equal "$VAL" "bar" "iniset created file"

# test creation of keys with spaces
iniset ${SUDO_ARG} ${TEST_INI} key_with_spaces "rgw another key" somethingelse
VAL=$(iniget ${TEST_INI} key_with_spaces "rgw another key")
assert_equal "$VAL" "somethingelse" "iniset created a key with spaces"

# test update of keys with spaces
iniset ${SUDO_ARG} ${TEST_INI} key_with_spaces "rgw special key" newvalue
VAL=$(iniget ${TEST_INI} key_with_spaces "rgw special key")
assert_equal "$VAL" "newvalue" "iniset updated a key with spaces"

inidelete ${SUDO_ARG} ${TEST_INI} key_with_spaces "rgw another key"
VAL=$(iniget ${TEST_INI} key_with_spaces "rgw another key")
assert_empty VAL "inidelete removed a key with spaces"

$SUDO rm -rf ${INI_TMP_DIR}

report_results
