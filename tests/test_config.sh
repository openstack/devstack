#!/usr/bin/env bash

# Tests for DevStack meta-config functions

TOP=$(cd $(dirname "$0")/.. && pwd)

# Import common functions
source $TOP/functions

# Import config functions
source $TOP/lib/config

# check_result() tests and reports the result values
# check_result "actual" "expected"
function check_result {
    local actual=$1
    local expected=$2
    if [[ "$actual" == "$expected" ]]; then
        echo "OK"
    else
        echo -e "failed: $actual != $expected\n"
    fi
}

TEST_1C_ADD="[eee]
type=new
multi = foo2"

function create_test1c {
    cat >test1c.conf <<EOF
[eee]
# original comment
type=original
EOF
}

function create_test2a {
    cat >test2a.conf <<EOF
[ddd]
# original comment
type=original
EOF
}

function setup_test4 {
    mkdir -p test-etc
    cat >test-etc/test4.conf <<EOF
[fff]
# original comment
type=original
EOF
    TEST4_DIR="test-etc"
    TEST4_FILE="test4.conf"
}

cat >test.conf <<EOF
[[test1|test1a.conf]]
[default]
# comment an option
#log_file=./log.conf
log_file=/etc/log.conf
handlers=do not disturb

[aaa]
# the commented option should not change
#handlers=cc,dd
handlers = aa, bb

[[test1|test1b.conf]]
[bbb]
handlers=ee,ff

[ ccc ]
spaces  =  yes

[[test2|test2a.conf]]
[ddd]
# new comment
type=new
additional=true

[[test1|test1c.conf]]
$TEST_1C_ADD

[[test3|test-space.conf]]
[DEFAULT]
attribute=value
 
# the above line has a single space

[[test4|\$TEST4_DIR/\$TEST4_FILE]]
[fff]
type=new
EOF

echo -n "get_meta_section_files: test0 doesn't exist: "
VAL=$(get_meta_section_files test.conf test0)
check_result "$VAL" ""

echo -n "get_meta_section_files: test1 3 files: "
VAL=$(get_meta_section_files test.conf test1)
EXPECT_VAL="test1a.conf
test1b.conf
test1c.conf"
check_result "$VAL" "$EXPECT_VAL"

echo -n "get_meta_section_files: test2 1 file: "
VAL=$(get_meta_section_files test.conf test2)
EXPECT_VAL="test2a.conf"
check_result "$VAL" "$EXPECT_VAL"


# Get a section from a group that doesn't exist
echo -n "get_meta_section: test0 doesn't exist: "
VAL=$(get_meta_section test.conf test0 test0.conf)
check_result "$VAL" ""

# Get a single section from a group with multiple files
echo -n "get_meta_section: test1c single section: "
VAL=$(get_meta_section test.conf test1 test1c.conf)
check_result "$VAL" "$TEST_1C_ADD"

# Get a single section from a group with a single file
echo -n "get_meta_section: test2a single section: "
VAL=$(get_meta_section test.conf test2 test2a.conf)
EXPECT_VAL="[ddd]
# new comment
type=new
additional=true"
check_result "$VAL" "$EXPECT_VAL"

# Get a single section that doesn't exist from a group
echo -n "get_meta_section: test2z.conf not in test2: "
VAL=$(get_meta_section test.conf test2 test2z.conf)
check_result "$VAL" ""

# Get a section from a conf file that doesn't exist
echo -n "get_meta_section: nofile doesn't exist: "
VAL=$(get_meta_section nofile.ini test1)
check_result "$VAL" ""

echo -n "get_meta_section: nofile doesn't exist: "
VAL=$(get_meta_section nofile.ini test0 test0.conf)
check_result "$VAL" ""

echo -n "merge_config_file test1c exists: "
create_test1c
merge_config_file test.conf test1 test1c.conf
VAL=$(cat test1c.conf)
# iniset adds values immediately under the section header
EXPECT_VAL="[eee]
multi = foo2
# original comment
type=new"
check_result "$VAL" "$EXPECT_VAL"

echo -n "merge_config_file test2a exists: "
create_test2a
merge_config_file test.conf test2 test2a.conf
VAL=$(cat test2a.conf)
# iniset adds values immediately under the section header
EXPECT_VAL="[ddd]
additional = true
# original comment
type=new"
check_result "$VAL" "$EXPECT_VAL"

echo -n "merge_config_file test2a not exist: "
rm test2a.conf
merge_config_file test.conf test2 test2a.conf
VAL=$(cat test2a.conf)
# iniset adds a blank line if it creates the file...
EXPECT_VAL="
[ddd]
additional = true
type = new"
check_result "$VAL" "$EXPECT_VAL"

echo -n "merge_config_group test2: "
rm test2a.conf
merge_config_group test.conf test2
VAL=$(cat test2a.conf)
# iniset adds a blank line if it creates the file...
EXPECT_VAL="
[ddd]
additional = true
type = new"
check_result "$VAL" "$EXPECT_VAL"

echo -n "merge_config_group test2 no conf file: "
rm test2a.conf
merge_config_group x-test.conf test2
if [[ ! -r test2a.conf ]]; then
    echo "OK"
else
    echo "failed: $VAL != $EXPECT_VAL"
fi

echo -n "merge_config_file test-space: "
rm -f test-space.conf
merge_config_file test.conf test3 test-space.conf
VAL=$(cat test-space.conf)
# iniset adds a blank line if it creates the file...
EXPECT_VAL="
[DEFAULT]
attribute = value"
check_result "$VAL" "$EXPECT_VAL"

echo -n "merge_config_group test4 variable filename: "
setup_test4
merge_config_group test.conf test4
VAL=$(cat test-etc/test4.conf)
EXPECT_VAL="[fff]
# original comment
type=new"
check_result "$VAL" "$EXPECT_VAL"

echo -n "merge_config_group test4 variable filename (not exist): "
setup_test4
rm test-etc/test4.conf
merge_config_group test.conf test4
VAL=$(cat test-etc/test4.conf)
EXPECT_VAL="
[fff]
type = new"
check_result "$VAL" "$EXPECT_VAL"

rm -f test.conf test1c.conf test2a.conf test-space.conf
rm -rf test-etc
