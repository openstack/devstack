#!/bin/bash

# exit on error to stop unexpected errors
set -o errexit
set -o xtrace

EXECUTOR_NUMBER=$1
CONFIGURATION=$2
ADAPTER=$3
RC=$4

function usage {
    echo "Usage: $0 - Build a test configuration"
    echo ""
    echo "$0 [EXECUTOR_NUMBER] [CONFIGURATION] [ADAPTER] [RC (optional)]"
    exit 1
}

# Validate inputs
if [[ "$EXECUTOR_NUMBER" = "" || "$CONFIGURATION" = ""  || "$ADAPTER" = "" ]]; then
    usage
fi

# This directory
CUR_DIR=$(cd $(dirname "$0") && pwd)

# devstack directory
cd ../../..
TOP_DIR=$(pwd)

# Deps
apt-get install -y --force-yes libvirt-bin || true

# Name test instance based on executor
BASE_NAME=executor-`printf "%02d" $EXECUTOR_NUMBER`
GUEST_NAME=$BASE_NAME.$ADAPTER
virsh list | grep $BASE_NAME | cut -d " " -f1 | xargs -n 1 virsh destroy || true
virsh net-list | grep $BASE_NAME | cut -d " " -f1 | xargs -n 1 virsh net-destroy || true

# Configure localrc
cat <<EOF >localrc
RECLONE=yes
GUEST_NETWORK=$EXECUTOR_NUMBER
GUEST_NAME=$GUEST_NAME
FLOATING_RANGE=192.168.$EXECUTOR_NUMBER.128/27
GUEST_CORES=1
GUEST_RAM=12574720
MYSQL_PASSWORD=chicken
RABBIT_PASSWORD=chicken
SERVICE_TOKEN=chicken
SERVICE_PASSWORD=chicken
ADMIN_PASSWORD=chicken
USERNAME=admin
TENANT=admin
NET_NAME=$BASE_NAME
ACTIVE_TIMEOUT=45
BOOT_TIMEOUT=45
$RC
EOF
cd tools
sudo ./build_uec.sh

# Make the address of the instances available to test runners
echo HEAD=`cat /var/lib/libvirt/dnsmasq/$BASE_NAME.leases | cut -d " " -f3` > $TOP_DIR/addresses
