#!/bin/bash

# Tests for functions.
#
# The tests are sourcing the mocks file to mock out various functions. The
# mocking-out always happens in a sub-shell, thus it does not have impact on
# the functions defined here.

# To run the tests, please run:
#
# ./test_functions.sh run_tests
#
# To only print out the discovered test functions, run:
#
# ./test_functions.sh

. functions

# Setup
function before_each_test {
    LIST_OF_DIRECTORIES=$(mktemp)
    truncate -s 0 $LIST_OF_DIRECTORIES

    LIST_OF_ACTIONS=$(mktemp)
    truncate -s 0 $LIST_OF_ACTIONS

    XE_RESPONSE=$(mktemp)
    truncate -s 0 $XE_RESPONSE

    XE_CALLS=$(mktemp)
    truncate -s 0 $XE_CALLS
}

# Teardown
function after_each_test {
    rm -f $LIST_OF_DIRECTORIES
    rm -f $LIST_OF_ACTIONS
    rm -f $XE_RESPONSE
    rm -f $XE_CALLS
}

# Helpers
function setup_xe_response {
    echo "$1" > $XE_RESPONSE
}

function given_directory_exists {
    echo "$1" >> $LIST_OF_DIRECTORIES
}

function assert_directory_exists {
    grep "$1" $LIST_OF_DIRECTORIES
}

function assert_previous_command_failed {
    [ "$?" != "0" ] || exit 1
}

function assert_xe_min {
    grep -qe "^--minimal\$" $XE_CALLS
}

function assert_xe_param {
    grep -qe "^$1\$" $XE_CALLS
}

function mock_out {
    local FNNAME="$1"
    local OUTPUT="$2"

    . <(cat << EOF
function $FNNAME {
    echo "$OUTPUT"
}
EOF
)
}

function assert_symlink {
    grep -qe "^ln -s $2 $1\$" $LIST_OF_ACTIONS
}

# Tests
function test_plugin_directory_on_xenserver {
    given_directory_exists "/etc/xapi.d/plugins/"

    PLUGDIR=$(. mocks && xapi_plugin_location)

    [ "/etc/xapi.d/plugins/" = "$PLUGDIR" ]
}

function test_plugin_directory_on_xcp {
    given_directory_exists "/usr/lib/xcp/plugins/"

    PLUGDIR=$(. mocks && xapi_plugin_location)

    [ "/usr/lib/xcp/plugins/" = "$PLUGDIR" ]
}

function test_no_plugin_directory_found {
    set +e

    local IGNORE
    IGNORE=$(. mocks && xapi_plugin_location)

    assert_previous_command_failed

    grep "[ -d /etc/xapi.d/plugins/ ]" $LIST_OF_ACTIONS
    grep "[ -d /usr/lib/xcp/plugins/ ]" $LIST_OF_ACTIONS
}

function test_zip_snapshot_location {
    diff \
    <(zip_snapshot_location "https://github.com/openstack/nova.git" "master") \
    <(echo "https://github.com/openstack/nova/zipball/master")
}

function test_create_directory_for_kernels {
    (
        . mocks
        mock_out get_local_sr uuid1
        create_directory_for_kernels
    )

    assert_directory_exists "/var/run/sr-mount/uuid1/os-guest-kernels"
    assert_symlink "/boot/guest" "/var/run/sr-mount/uuid1/os-guest-kernels"
}

function test_create_directory_for_kernels_existing_dir {
    (
        . mocks
        given_directory_exists "/boot/guest"
        create_directory_for_kernels
    )

    diff -u $LIST_OF_ACTIONS - << EOF
[ -d /boot/guest ]
EOF
}

function test_create_directory_for_images {
    (
        . mocks
        mock_out get_local_sr uuid1
        create_directory_for_images
    )

    assert_directory_exists "/var/run/sr-mount/uuid1/os-images"
    assert_symlink "/images" "/var/run/sr-mount/uuid1/os-images"
}

function test_create_directory_for_images_existing_dir {
    (
        . mocks
        given_directory_exists "/images"
        create_directory_for_images
    )

    diff -u $LIST_OF_ACTIONS - << EOF
[ -d /images ]
EOF
}

function test_extract_remote_zipball {
    local RESULT=$(. mocks && extract_remote_zipball "someurl")

    diff <(cat $LIST_OF_ACTIONS) - << EOF
wget -nv someurl -O tempfile --no-check-certificate
unzip -q -o tempfile -d tempdir
rm -f tempfile
EOF

    [ "$RESULT" = "tempdir" ]
}

function test_extract_remote_zipball_wget_fail {
    set +e

    local IGNORE
    IGNORE=$(. mocks && extract_remote_zipball "failurl")

    assert_previous_command_failed
}

function test_find_nova_plugins {
    local tmpdir=$(mktemp -d)

    mkdir -p "$tmpdir/blah/blah/u/xapi.d/plugins"

    [ "$tmpdir/blah/blah/u/xapi.d/plugins" = $(find_xapi_plugins_dir $tmpdir) ]

    rm -rf $tmpdir
}

function test_get_local_sr {
    setup_xe_response "uuid123"

    local RESULT=$(. mocks && get_local_sr)

    [ "$RESULT" == "uuid123" ]

    assert_xe_min
    assert_xe_param "sr-list" "name-label=Local storage"
}

function test_get_local_sr_path {
    local RESULT=$(mock_out get_local_sr "uuid1" && get_local_sr_path)

    [ "/var/run/sr-mount/uuid1" == "$RESULT" ]
}

# Test runner
[ "$1" = "" ] && {
    grep -e "^function *test_" $0 | cut -d" " -f2
}

[ "$1" = "run_tests" ] && {
    for testname in $($0)
    do
        echo "$testname"
        before_each_test
        (
            set -eux
            $testname
        )
        if [ "$?" != "0" ]
        then
            echo "FAIL"
            exit 1
        else
            echo "PASS"
        fi

        after_each_test
    done
}
