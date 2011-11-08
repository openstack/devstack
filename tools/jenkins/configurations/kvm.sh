#!/bin/bash

EXECUTOR_NUMBER=$1
CONFIGURATION=$2

function usage() {
    echo "Usage: $0 - Build a test configuration"
    echo ""
    echo "$0 [EXECUTOR_NUMBER] [CONFIGURATION]"
    exit 1
}

# Validate inputs
if [[ "$EXECUTOR_NUMBER" = "" || "$CONFIGURATION" = "" ]]; then
    usage
fi

# This directory
CUR_DIR=$(cd $(dirname "$0") && pwd)

# devstack directory
cd ../../..
TOP_DIR=(pwd)

# Name test instance based on executor
NAME=executor-$EXECUTOR_NUMBER
virsh destroy `virsh list | grep $NAME | cut -d " " -f1` || true

# Configure localrc
cat <<EOF >localrc
RECLONE=yes
GUEST_NETWORK=$EXECUTOR_NUMBER
GUEST_NAME=$NAME
FLOATING_RANGE=192.168.$EXECUTOR_NUMBER.128/27
GUEST_CORES=4
GUEST_RAM=10000000
MYSQL_PASSWORD=chicken
RABBIT_PASSWORD=chicken
SERVICE_TOKEN=chicken
ADMIN_PASSWORD=chicken
USERNAME=admin
TENANT=admin
EOF
cd tools
sudo ./build_uec.sh
