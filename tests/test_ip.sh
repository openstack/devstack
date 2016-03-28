#!/usr/bin/env bash

# Tests for DevStack functions
# address_in_net()

TOP=$(cd $(dirname "$0")/.. && pwd)

# Import common functions
source $TOP/functions

source $TOP/tests/unittest.sh

echo "Testing IP addr functions"

function test_cidr2netmask {
    local mask=0
    local ips="128 192 224 240 248 252 254 255"
    local ip
    local msg

    msg="cidr2netmask(/0) == 0.0.0.0"
    assert_equal "0.0.0.0" $(cidr2netmask $mask) "$msg"

    for ip in $ips; do
        mask=$(( mask + 1 ))
        msg="cidr2netmask(/$mask) == $ip.0.0.0"
        assert_equal "$ip.0.0.0" $(cidr2netmask $mask) "$msg"
    done

    for ip in $ips; do
        mask=$(( mask + 1 ))
        msg="cidr2netmask(/$mask) == 255.$ip.0.0"
        assert_equal "255.$ip.0.0" $(cidr2netmask $mask) "$msg"
    done

    for ip in $ips; do
        mask=$(( mask + 1 ))
        msg="cidr2netmask(/$mask) == 255.255.$ip.0"
        assert_equal "255.255.$ip.0" $(cidr2netmask $mask) "$msg"
    done

    for ip in $ips; do
        mask=$(( mask + 1 ))
        msg="cidr2netmask(/$mask) == 255.255.255.$ip"
        assert_equal "255.255.255.$ip" $(cidr2netmask $mask) "$msg"
    done
}

test_cidr2netmask

msg="maskip(169.254.169.254 240.0.0.0) == 160.0.0.0"
assert_equal $(maskip 169.254.169.254 240.0.0.0) 160.0.0.0 "$msg"

msg="maskip(169.254.169.254 255.0.0.0) == 169.0.0.0"
assert_equal $(maskip 169.254.169.254 255.0.0.0) 169.0.0.0 "$msg"

msg="maskip(169.254.169.254 255.240.0.0) == 169.240.0.0"
assert_equal $(maskip 169.254.169.254 255.240.0.0) 169.240.0.0 "$msg"

msg="maskip(169.254.169.254 255.255.0.0) == 169.254.0.0"
assert_equal $(maskip 169.254.169.254 255.255.0.0) 169.254.0.0 "$msg"

msg="maskip(169.254.169.254 255.255.240.0) == 169.254.160.0"
assert_equal $(maskip 169.254.169.254 255.255.240.0) 169.254.160.0 "$msg"

msg="maskip(169.254.169.254 255.255.255.0) == 169.254.169.0"
assert_equal $(maskip 169.254.169.254 255.255.255.0) 169.254.169.0 "$msg"

msg="maskip(169.254.169.254 255.255.255.240) == 169.254.169.240"
assert_equal $(maskip 169.254.169.254 255.255.255.240) 169.254.169.240 "$msg"

msg="maskip(169.254.169.254 255.255.255.255) == 169.254.169.254"
assert_equal $(maskip 169.254.169.254 255.255.255.255) 169.254.169.254 "$msg"


for mask in 8 12 16 20 24 26 28; do
    msg="address_in_net($10.10.10.1 10.10.10.0/$mask)"
    if address_in_net 10.10.10.1 10.10.10.0/$mask; then
        passed "$msg"
    else
        failed "$msg"
    fi

    msg="! address_in_net($10.10.10.1 11.11.11.0/$mask)"
    if ! address_in_net 10.10.10.1 11.11.11.0/$mask; then
        passed "$msg"
    else
        failed "$msg"
    fi
done

report_results
