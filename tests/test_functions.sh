#!/usr/bin/env bash

# Tests for DevStack functions

TOP=$(cd $(dirname "$0")/.. && pwd)

# Import common functions
source $TOP/functions

source $TOP/tests/unittest.sh

echo "Testing generate_hex_string()"

VAL=$(generate_hex_string 16)
if [[ ${#VAL} -eq 32 ]]; then
    passed "OK"
else
    failed "generate_hex_string 16 failed ${#VAL}"
fi

VAL=$(generate_hex_string 32)
if [[ ${#VAL} -eq 64 ]]; then
    passed "OK"
else
    failed "generate_hex_string 32 failed ${#VAL}"
fi

echo "Testing die_if_not_set()"

bash -c "source $TOP/functions; X=`echo Y && true`; die_if_not_set $LINENO X 'not OK'"
if [[ $? != 0 ]]; then
    failed "die_if_not_set [X='Y' true] Failed"
else
    passed 'OK'
fi

bash -c "source $TOP/functions; X=`true`; die_if_not_set $LINENO X 'OK'" > /dev/null 2>&1
if [[ $? = 0 ]]; then
    failed "die_if_not_set [X='' true] Failed"
fi

bash -c "source $TOP/functions; X=`echo Y && false`; die_if_not_set $LINENO X 'not OK'"
if [[ $? != 0 ]]; then
    failed "die_if_not_set [X='Y' false] Failed"
else
    passed 'OK'
fi

bash -c "source $TOP/functions; X=`false`; die_if_not_set $LINENO X 'OK'" > /dev/null 2>&1
if [[ $? = 0 ]]; then
    failed "die_if_not_set [X='' false] Failed"
fi


# Enabling/disabling services

echo "Testing enable_service()"

function test_enable_service {
    local start="$1"
    local add="$2"
    local finish="$3"

    ENABLED_SERVICES="$start"
    enable_service $add
    if [ "$ENABLED_SERVICES" = "$finish" ]; then
        passed "OK: $start + $add -> $ENABLED_SERVICES"
    else
        failed "changing $start to $finish with $add failed: $ENABLED_SERVICES"
    fi
}

test_enable_service '' a 'a'
test_enable_service 'a' b 'a,b'
test_enable_service 'a,b' c 'a,b,c'
test_enable_service 'a,b' c 'a,b,c'
test_enable_service 'a,b,' c 'a,b,c'
test_enable_service 'a,b' c,d 'a,b,c,d'
test_enable_service 'a,b' "c d" 'a,b,c,d'
test_enable_service 'a,b,c' c 'a,b,c'

test_enable_service 'a,b,-c' c 'a,b'
test_enable_service 'a,b,c' -c 'a,b'

function test_disable_service {
    local start="$1"
    local del="$2"
    local finish="$3"

    ENABLED_SERVICES="$start"
    disable_service "$del"
    if [ "$ENABLED_SERVICES" = "$finish" ]; then
        passed "OK: $start - $del -> $ENABLED_SERVICES"
    else
        failed "changing $start to $finish with $del failed: $ENABLED_SERVICES"
    fi
}

echo "Testing disable_service()"
test_disable_service 'a,b,c' a 'b,c'
test_disable_service 'a,b,c' b 'a,c'
test_disable_service 'a,b,c' c 'a,b'

test_disable_service 'a,b,c' a 'b,c'
test_disable_service 'b,c' b 'c'
test_disable_service 'c' c ''
test_disable_service '' d ''

test_disable_service 'a,b,c,' c 'a,b'
test_disable_service 'a,b' c 'a,b'


echo "Testing disable_all_services()"
ENABLED_SERVICES=a,b,c
disable_all_services

if [[ -z "$ENABLED_SERVICES" ]]; then
    passed "OK"
else
    failed "disabling all services FAILED: $ENABLED_SERVICES"
fi

echo "Testing disable_negated_services()"


function test_disable_negated_services {
    local start="$1"
    local finish="$2"

    ENABLED_SERVICES="$start"
    disable_negated_services
    if [ "$ENABLED_SERVICES" = "$finish" ]; then
        passed "OK: $start + $add -> $ENABLED_SERVICES"
    else
        failed "changing $start to $finish failed: $ENABLED_SERVICES"
    fi
}

test_disable_negated_services '-a' ''
test_disable_negated_services '-a,a' ''
test_disable_negated_services '-a,-a' ''
test_disable_negated_services 'a,-a' ''
test_disable_negated_services 'b,a,-a' 'b'
test_disable_negated_services 'a,b,-a' 'b'
test_disable_negated_services 'a,-a,b' 'b'
test_disable_negated_services 'a,aa,-a' 'aa'
test_disable_negated_services 'aa,-a' 'aa'
test_disable_negated_services 'a_a, -a_a' ''
test_disable_negated_services 'a-b, -a-b' ''
test_disable_negated_services 'a-b, b, -a-b' 'b'
test_disable_negated_services 'a,-a,av2,b' 'av2,b'
test_disable_negated_services 'a,aa,-a' 'aa'
test_disable_negated_services 'a,av2,-a,a' 'av2'
test_disable_negated_services 'a,-a,av2' 'av2'

echo "Testing remove_disabled_services()"

function test_remove_disabled_services {
    local service_list="$1"
    local remove_list="$2"
    local expected="$3"

    results=$(remove_disabled_services "$service_list" "$remove_list")
    if [ "$results" = "$expected" ]; then
        passed "OK: '$service_list' - '$remove_list' -> '$results'"
    else
        failed "getting '$expected' from '$service_list' - '$remove_list' failed: '$results'"
    fi
}

test_remove_disabled_services 'a,b,c' 'a,c' 'b'
test_remove_disabled_services 'a,b,c' 'b' 'a,c'
test_remove_disabled_services 'a,b,c,d' 'a,c d' 'b'
test_remove_disabled_services 'a,b c,d' 'a d' 'b,c'
test_remove_disabled_services 'a,b,c' 'a,b,c' ''
test_remove_disabled_services 'a,b,c' 'd' 'a,b,c'
test_remove_disabled_services 'a,b,c' '' 'a,b,c'
test_remove_disabled_services '' 'a,b,c' ''
test_remove_disabled_services '' '' ''

echo "Testing is_package_installed()"

if [[ -z "$os_PACKAGE" ]]; then
    GetOSVersion
fi

if [[ "$os_PACKAGE" = "deb" ]]; then
    is_package_installed dpkg
    VAL=$?
elif [[ "$os_PACKAGE" = "rpm" ]]; then
    is_package_installed rpm
    VAL=$?
else
    VAL=1
fi
if [[ "$VAL" -eq 0 ]]; then
    passed "OK"
else
    failed "is_package_installed() on existing package failed"
fi

if [[ "$os_PACKAGE" = "deb" ]]; then
    is_package_installed dpkg bash
    VAL=$?
elif [[ "$os_PACKAGE" = "rpm" ]]; then
    is_package_installed rpm bash
    VAL=$?
else
    VAL=1
fi
if [[ "$VAL" -eq 0 ]]; then
    passed "OK"
else
    failed "is_package_installed() on more than one existing package failed"
fi

is_package_installed zzzZZZzzz
VAL=$?
if [[ "$VAL" -ne 0 ]]; then
    passed "OK"
else
    failed "is_package_installed() on non-existing package failed"
fi

# test against removed package...was a bug on Ubuntu
if is_ubuntu; then
    PKG=cowsay-off
    if ! (dpkg -s $PKG >/dev/null 2>&1); then
        # it was never installed...set up the condition
        sudo apt-get install -y cowsay >/dev/null 2>&1
    fi
    if (dpkg -s $PKG >/dev/null 2>&1); then
        # remove it to create the 'un' status
        sudo dpkg -P $PKG >/dev/null 2>&1
    fi

    # now test the installed check on a deleted package
    is_package_installed $PKG
    VAL=$?
    if [[ "$VAL" -ne 0 ]]; then
        passed "OK"
    else
        failed "is_package_installed() on deleted package failed"
    fi
fi

# test isset function
echo  "Testing isset()"
you_should_not_have_this_variable=42

if isset "you_should_not_have_this_variable"; then
    passed "OK"
else
    failed "\"you_should_not_have_this_variable\" not declared. failed"
fi

unset you_should_not_have_this_variable
if isset "you_should_not_have_this_variable"; then
    failed "\"you_should_not_have_this_variable\" looks like declared variable."
else
    passed "OK"
fi

function test_export_proxy_variables {
    echo "Testing export_proxy_variables()"

    local expected results

    http_proxy=http_proxy_test
    https_proxy=https_proxy_test
    no_proxy=no_proxy_test

    export_proxy_variables
    expected=$(echo -e "http_proxy=$http_proxy\nhttps_proxy=$https_proxy\nno_proxy=$no_proxy")
    results=$(env | egrep '(http(s)?|no)_proxy=' | sort)
    if [[ $expected = $results ]]; then
        passed "OK: Proxy variables are exported when proxy variables are set"
    else
        failed "Expected: $expected, Failed: $results"
    fi

    unset http_proxy https_proxy no_proxy
    export_proxy_variables
    results=$(env | egrep '(http(s)?|no)_proxy=')
    if [[ "" = $results ]]; then
        passed "OK: Proxy variables aren't exported when proxy variables aren't set"
    else
        failed "Expected: '', Failed: $results"
    fi
}
test_export_proxy_variables

report_results
