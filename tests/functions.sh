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


echo "Testing INI functions"

cat >test.ini <<EOF
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
EOF

# Test with spaces

VAL=$(iniget test.ini aaa handlers)
if [[ "$VAL" == "aa, bb" ]]; then
    echo "OK: $VAL"
else
    echo "iniget failed: $VAL"
fi

iniset test.ini aaa handlers "11, 22"

VAL=$(iniget test.ini aaa handlers)
if [[ "$VAL" == "11, 22" ]]; then
    echo "OK: $VAL"
else
    echo "iniget failed: $VAL"
fi

# Test with spaces in section header

VAL=$(iniget test.ini " ccc " spaces)
if [[ "$VAL" == "yes" ]]; then
    echo "OK: $VAL"
else
    echo "iniget failed: $VAL"
fi

iniset test.ini "b b" opt_ion 42

VAL=$(iniget test.ini "b b" opt_ion)
if [[ "$VAL" == "42" ]]; then
    echo "OK: $VAL"
else
    echo "iniget failed: $VAL"
fi

# Test without spaces, end of file

VAL=$(iniget test.ini bbb handlers)
if [[ "$VAL" == "ee,ff" ]]; then
    echo "OK: $VAL"
else
    echo "iniget failed: $VAL"
fi

iniset test.ini bbb handlers "33,44"

VAL=$(iniget test.ini bbb handlers)
if [[ "$VAL" == "33,44" ]]; then
    echo "OK: $VAL"
else
    echo "iniget failed: $VAL"
fi

# test empty option
if ini_has_option test.ini ddd empty; then
    echo "OK: ddd.empty present"
else
    echo "ini_has_option failed: ddd.empty not found"
fi

# test non-empty option
if ini_has_option test.ini bbb handlers; then
    echo "OK: bbb.handlers present"
else
    echo "ini_has_option failed: bbb.handlers not found"
fi

# test changing empty option
iniset test.ini ddd empty "42"

VAL=$(iniget test.ini ddd empty)
if [[ "$VAL" == "42" ]]; then
    echo "OK: $VAL"
else
    echo "iniget failed: $VAL"
fi

# Test section not exist

VAL=$(iniget test.ini zzz handlers)
if [[ -z "$VAL" ]]; then
    echo "OK: zzz not present"
else
    echo "iniget failed: $VAL"
fi

iniset test.ini zzz handlers "999"

VAL=$(iniget test.ini zzz handlers)
if [[ -n "$VAL" ]]; then
    echo "OK: zzz not present"
else
    echo "iniget failed: $VAL"
fi

# Test option not exist

VAL=$(iniget test.ini aaa debug)
if [[ -z "$VAL" ]]; then
    echo "OK aaa.debug not present"
else
    echo "iniget failed: $VAL"
fi

if ! ini_has_option test.ini aaa debug; then
    echo "OK aaa.debug not present"
else
    echo "ini_has_option failed: aaa.debug"
fi

iniset test.ini aaa debug "999"

VAL=$(iniget test.ini aaa debug)
if [[ -n "$VAL" ]]; then
    echo "OK aaa.debug present"
else
    echo "iniget failed: $VAL"
fi

# Test comments

inicomment test.ini aaa handlers

VAL=$(iniget test.ini aaa handlers)
if [[ -z "$VAL" ]]; then
    echo "OK"
else
    echo "inicomment failed: $VAL"
fi

# Test multiple line iniset/iniget
iniset_multiline test.ini eee multi bar1 bar2

VAL=$(iniget_multiline test.ini eee multi)
if [[ "$VAL" == "bar1 bar2" ]]; then
    echo "OK: iniset_multiline"
else
    echo "iniset_multiline failed: $VAL"
fi

# Test iniadd with exiting values
iniadd test.ini eee multi bar3
VAL=$(iniget_multiline test.ini eee multi)
if [[ "$VAL" == "bar1 bar2 bar3" ]]; then
    echo "OK: iniadd"
else
    echo "iniadd failed: $VAL"
fi

# Test iniadd with non-exiting values
iniadd test.ini eee non-multi foobar1 foobar2
VAL=$(iniget_multiline test.ini eee non-multi)
if [[ "$VAL" == "foobar1 foobar2" ]]; then
    echo "OK: iniadd with non-exiting value"
else
    echo "iniadd with non-exsting failed: $VAL"
fi

rm test.ini

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
