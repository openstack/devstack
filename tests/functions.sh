#!/usr/bin/env bash

# Tests for DevStack functions

TOP=$(cd $(dirname "$0")/.. && pwd)

# Import common functions
source $TOP/functions

# Import configuration
source $TOP/openrc


echo "Testing die_if_not_set()"

bash -cx "source $TOP/functions; X=`echo Y && true`; die_if_not_set X 'not OK'"
if [[ $? != 0 ]]; then
    echo "die_if_not_set [X='Y' true] Failed"
else
    echo 'OK'
fi

bash -cx "source $TOP/functions; X=`true`; die_if_not_set X 'OK'"
if [[ $? = 0 ]]; then
    echo "die_if_not_set [X='' true] Failed"
fi

bash -cx "source $TOP/functions; X=`echo Y && false`; die_if_not_set X 'not OK'"
if [[ $? != 0 ]]; then
    echo "die_if_not_set [X='Y' false] Failed"
else
    echo 'OK'
fi

bash -cx "source $TOP/functions; X=`false`; die_if_not_set X 'OK'"
if [[ $? = 0 ]]; then
    echo "die_if_not_set [X='' false] Failed"
fi


# Enabling/disabling services

echo "Testing enable_service()"

function test_enable_service() {
    local start="$1"
    local add="$2"
    local finish="$3"

    ENABLED_SERVICES="$start"
    enable_service $add
    if [ "$ENABLED_SERVICES" = "$finish" ]
    then
        echo "OK: $start + $add -> $ENABLED_SERVICES"
    else
        echo "changing $start to $finish with $add failed: $ENABLED_SERVICES"
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

function test_disable_service() {
    local start="$1"
    local del="$2"
    local finish="$3"

    ENABLED_SERVICES="$start"
    disable_service "$del"
    if [ "$ENABLED_SERVICES" = "$finish" ]
    then
        echo "OK: $start - $del -> $ENABLED_SERVICES"
    else
        echo "changing $start to $finish with $del failed: $ENABLED_SERVICES"
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

if [[ -z "$ENABLED_SERVICES" ]]
then
    echo "OK"
else
    echo "disabling all services FAILED: $ENABLED_SERVICES"
fi

echo "Testing disable_negated_services()"


function test_disable_negated_services() {
    local start="$1"
    local finish="$2"

    ENABLED_SERVICES="$start"
    disable_negated_services
    if [ "$ENABLED_SERVICES" = "$finish" ]
    then
        echo "OK: $start + $add -> $ENABLED_SERVICES"
    else
        echo "changing $start to $finish failed: $ENABLED_SERVICES"
    fi
}

test_disable_negated_services '-a' ''
test_disable_negated_services '-a,a' ''
test_disable_negated_services '-a,-a' ''
test_disable_negated_services 'a,-a' ''
test_disable_negated_services 'b,a,-a' 'b'
test_disable_negated_services 'a,b,-a' 'b'
test_disable_negated_services 'a,-a,b' 'b'


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
    echo "OK"
else
    echo "is_package_installed() on existing package failed"
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
    echo "OK"
else
    echo "is_package_installed() on more than one existing package failed"
fi

is_package_installed zzzZZZzzz
VAL=$?
if [[ "$VAL" -ne 0 ]]; then
    echo "OK"
else
    echo "is_package_installed() on non-existing package failed"
fi

# test against removed package...was a bug on Ubuntu
if is_ubuntu; then
    PKG=cowsay
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
        echo "OK"
    else
        echo "is_package_installed() on deleted package failed"
    fi
fi
