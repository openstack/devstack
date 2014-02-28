#!/bin/bash
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

# Configuration of xenrc
XENRC=/var/lib/jenkins/xenrc
if [ ! -e $XENRC ]; then
    echo "/var/lib/jenkins/xenrc is not present! See README.md"
    exit 1
fi

# Move to top of devstack
cd ../../..

# Use xenrc as the start of our localrc
cp $XENRC localrc

# Set the PUB_IP
PUB_IP=192.168.1.1$EXECUTOR_NUMBER
echo "PUB_IP=$PUB_IP" >> localrc

# Overrides
echo "$RC" >> localrc

# Source localrc
. localrc

# Make host ip available to tester
echo "HEAD=$PUB_IP" > addresses

# Build configuration
REMOTE_DEVSTACK=/root/devstack
ssh root@$XEN_IP "rm -rf $REMOTE_DEVSTACK"
scp -pr . root@$XEN_IP:$REMOTE_DEVSTACK
ssh root@$XEN_IP "cd $REMOTE_DEVSTACK/tools/xen && ./build_domU.sh"
