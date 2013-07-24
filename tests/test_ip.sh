#!/usr/bin/env bash

# Tests for DevStack functions
# address_in_net()

TOP=$(cd $(dirname "$0")/.. && pwd)

# Import common functions
source $TOP/functions

# Import configuration
source $TOP/openrc


echo "Testing IP addr functions"

if [[ $(cidr2netmask 4) == 240.0.0.0 ]]; then
    echo "cidr2netmask(): /4...OK"
else
    echo "cidr2netmask(): /4...failed"
fi
if [[ $(cidr2netmask 8) == 255.0.0.0 ]]; then
    echo "cidr2netmask(): /8...OK"
else
    echo "cidr2netmask(): /8...failed"
fi
if [[ $(cidr2netmask 12) == 255.240.0.0 ]]; then
    echo "cidr2netmask(): /12...OK"
else
    echo "cidr2netmask(): /12...failed"
fi
if [[ $(cidr2netmask 16) == 255.255.0.0 ]]; then
    echo "cidr2netmask(): /16...OK"
else
    echo "cidr2netmask(): /16...failed"
fi
if [[ $(cidr2netmask 20) == 255.255.240.0 ]]; then
    echo "cidr2netmask(): /20...OK"
else
    echo "cidr2netmask(): /20...failed"
fi
if [[ $(cidr2netmask 24) == 255.255.255.0 ]]; then
    echo "cidr2netmask(): /24...OK"
else
    echo "cidr2netmask(): /24...failed"
fi
if [[ $(cidr2netmask 28) == 255.255.255.240 ]]; then
    echo "cidr2netmask(): /28...OK"
else
    echo "cidr2netmask(): /28...failed"
fi
if [[ $(cidr2netmask 30) == 255.255.255.252 ]]; then
    echo "cidr2netmask(): /30...OK"
else
    echo "cidr2netmask(): /30...failed"
fi
if [[ $(cidr2netmask 32) == 255.255.255.255 ]]; then
    echo "cidr2netmask(): /32...OK"
else
    echo "cidr2netmask(): /32...failed"
fi

if [[ $(maskip 169.254.169.254 240.0.0.0) == 160.0.0.0 ]]; then
    echo "maskip(): /4...OK"
else
    echo "maskip(): /4...failed"
fi
if [[ $(maskip 169.254.169.254 255.0.0.0) == 169.0.0.0 ]]; then
    echo "maskip(): /8...OK"
else
    echo "maskip(): /8...failed"
fi
if [[ $(maskip 169.254.169.254 255.240.0.0) == 169.240.0.0 ]]; then
    echo "maskip(): /12...OK"
else
    echo "maskip(): /12...failed"
fi
if [[ $(maskip 169.254.169.254 255.255.0.0) == 169.254.0.0 ]]; then
    echo "maskip(): /16...OK"
else
    echo "maskip(): /16...failed"
fi
if [[ $(maskip 169.254.169.254 255.255.240.0) == 169.254.160.0 ]]; then
    echo "maskip(): /20...OK"
else
    echo "maskip(): /20...failed"
fi
if [[ $(maskip 169.254.169.254 255.255.255.0) == 169.254.169.0 ]]; then
    echo "maskip(): /24...OK"
else
    echo "maskip(): /24...failed"
fi
if [[ $(maskip 169.254.169.254 255.255.255.240) == 169.254.169.240 ]]; then
    echo "maskip(): /28...OK"
else
    echo "maskip(): /28...failed"
fi
if [[ $(maskip 169.254.169.254 255.255.255.255) == 169.254.169.254 ]]; then
    echo "maskip(): /32...OK"
else
    echo "maskip(): /32...failed"
fi

for mask in 8 12 16 20 24 26 28; do
    echo -n "address_in_net(): in /$mask..."
    if address_in_net 10.10.10.1 10.10.10.0/$mask; then
        echo "OK"
    else
        echo "address_in_net() failed on /$mask"
    fi

    echo -n "address_in_net(): not in /$mask..."
    if ! address_in_net 10.10.10.1 11.11.11.0/$mask; then
        echo "OK"
    else
        echo "address_in_net() failed on /$mask"
    fi
done
