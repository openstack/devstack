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
