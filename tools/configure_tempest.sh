#!/usr/bin/env bash
#
# **configure_tempest.sh**

# Build a tempest configuration file from devstack

echo "**************************************************"
echo "Configuring Tempest"
echo "**************************************************"

# This script exits on an error so that errors don't compound and you see
# only the first error that occured.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

function usage {
    echo "$0 - Build tempest.conf"
    echo ""
    echo "Usage: $0"
    exit 1
}

if [ "$1" = "-h" ]; then
    usage
fi

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $TOOLS_DIR/..; pwd)

# Import common functions
. $TOP_DIR/functions

# Abort if localrc is not set
if [ ! -e $TOP_DIR/localrc ]; then
    echo "You must have a localrc with necessary basic configuration defined before proceeding."
    exit 1
fi

# Abort if openrc is not set
if [ ! -e $TOP_DIR/openrc ]; then
    echo "You must have an openrc with ALL necessary passwords and credentials defined before proceeding."
    exit 1
fi

# Source params
source $TOP_DIR/openrc

# Where Openstack code lives
DEST=${DEST:-/opt/stack}

TEMPEST_DIR=$DEST/tempest
CONFIG_DIR=$TEMPEST_DIR/etc
TEMPEST_CONF=$CONFIG_DIR/tempest.conf

# Use the GUEST_IP unless an explicit IP is set by ``HOST_IP``
HOST_IP=${HOST_IP:-$GUEST_IP}
# Use the first IP if HOST_IP still is not set
if [ ! -n "$HOST_IP" ]; then
    HOST_IP=`LC_ALL=C /sbin/ifconfig  | grep -m 1 'inet addr:'| cut -d: -f2 | awk '{print $1}'`
fi

# Glance should already contain images to be used in tempest
# testing. Here we simply look for images stored in Glance
# and set the appropriate variables for use in the tempest config
# We ignore ramdisk and kernel images and set the IMAGE_UUID to
# the first image returned and set IMAGE_UUID_ALT to the second,
# if there is more than one returned...
# ... Also ensure we only take active images, so we don't get snapshots in process
IMAGE_LINES=`glance image-list`
IFS="$(echo -e "\n\r")"
IMAGES=""
for line in $IMAGE_LINES; do
    IMAGES="$IMAGES `echo $line | grep -v "^\(ID\|+--\)" | grep -v "\(aki\|ari\)" | grep 'active' | cut -d' ' -f2`"
done
# Create array of image UUIDs...
IFS=" "
IMAGES=($IMAGES)
NUM_IMAGES=${#IMAGES[*]}
echo "Found $NUM_IMAGES images"
if [[ $NUM_IMAGES -eq 0 ]]; then
    echo "Found no valid images to use!"
    exit 1
fi
IMAGE_UUID=${IMAGES[0]}
IMAGE_UUID_ALT=$IMAGE_UUID
if [[ $NUM_IMAGES -gt 1 ]]; then
    IMAGE_UUID_ALT=${IMAGES[1]}
fi

# Create tempest.conf from tempest.conf.tpl
# copy every time, because the image UUIDS are going to change
cp $TEMPEST_CONF.tpl $TEMPEST_CONF

ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-secrete}
ADMIN_TENANT_NAME=${ADMIN_TENANT:-admin}

IDENTITY_USE_SSL=${IDENTITY_USE_SSL:-False}
IDENTITY_HOST=${IDENTITY_HOST:-127.0.0.1}
IDENTITY_PORT=${IDENTITY_PORT:-5000}
IDENTITY_API_VERSION="v2.0" # Note: need v for now...
# TODO(jaypipes): This is dumb and needs to be removed
# from the Tempest configuration file entirely...
IDENTITY_PATH=${IDENTITY_PATH:-tokens}
IDENTITY_STRATEGY=${IDENTITY_STRATEGY:-keystone}

# We use regular, non-admin users in Tempest for the USERNAME
# substitutions and use ADMIN_USERNAME et al for the admin stuff.
# OS_USERNAME et all should be defined in openrc.
OS_USERNAME=${OS_USERNAME:-demo}
OS_TENANT_NAME=${OS_TENANT_NAME:-demo}
OS_PASSWORD=${OS_PASSWORD:$ADMIN_PASSWORD}

# See files/keystone_data.sh where alt_demo user
# and tenant are set up...
ALT_USERNAME=${ALT_USERNAME:-alt_demo}
ALT_TENANT_NAME=${ALT_TENANT_NAME:-alt_demo}
ALT_PASSWORD=$OS_PASSWORD

# TODO(jaypipes): Support configurable flavor refs here...
FLAVOR_REF=1
FLAVOR_REF_ALT=2

# Do any of the following need to be configurable?
COMPUTE_CATALOG_TYPE=compute
COMPUTE_CREATE_IMAGE_ENABLED=True
COMPUTE_RESIZE_AVAILABLE=False  # not supported with QEMU...
COMPUTE_LOG_LEVEL=ERROR
BUILD_INTERVAL=10
BUILD_TIMEOUT=600

# Image test configuration options...
IMAGE_HOST=${IMAGE_HOST:-127.0.0.1}
IMAGE_PORT=${IMAGE_PORT:-9292}
IMAGE_API_VERSION="1"

sed -e "
    s,%IDENTITY_USE_SSL%,$IDENTITY_USE_SSL,g;
    s,%IDENTITY_HOST%,$IDENTITY_HOST,g;
    s,%IDENTITY_PORT%,$IDENTITY_PORT,g;
    s,%IDENTITY_API_VERSION%,$IDENTITY_API_VERSION,g;
    s,%IDENTITY_PATH%,$IDENTITY_PATH,g;
    s,%IDENTITY_STRATEGY%,$IDENTITY_STRATEGY,g;
    s,%USERNAME%,$OS_USERNAME,g;
    s,%PASSWORD%,$OS_PASSWORD,g;
    s,%TENANT_NAME%,$OS_TENANT_NAME,g;
    s,%ALT_USERNAME%,$ALT_USERNAME,g;
    s,%ALT_PASSWORD%,$ALT_PASSWORD,g;
    s,%ALT_TENANT_NAME%,$ALT_TENANT_NAME,g;
    s,%COMPUTE_CATALOG_TYPE%,$COMPUTE_CATALOG_TYPE,g;
    s,%COMPUTE_CREATE_IMAGE_ENABLED%,$COMPUTE_CREATE_IMAGE_ENABLED,g;
    s,%COMPUTE_RESIZE_AVAILABLE%,$COMPUTE_RESIZE_AVAILABLE,g;
    s,%COMPUTE_LOG_LEVEL%,$COMPUTE_LOG_LEVEL,g;
    s,%BUILD_INTERVAL%,$BUILD_INTERVAL,g;
    s,%BUILD_TIMEOUT%,$BUILD_TIMEOUT,g;
    s,%IMAGE_ID%,$IMAGE_UUID,g;
    s,%IMAGE_ID_ALT%,$IMAGE_UUID_ALT,g;
    s,%FLAVOR_REF%,$FLAVOR_REF,g;
    s,%FLAVOR_REF_ALT%,$FLAVOR_REF_ALT,g;
    s,%IMAGE_HOST%,$IMAGE_HOST,g;
    s,%IMAGE_PORT%,$IMAGE_PORT,g;
    s,%IMAGE_API_VERSION%,$IMAGE_API_VERSION,g;
    s,%ADMIN_USERNAME%,$ADMIN_USERNAME,g;
    s,%ADMIN_PASSWORD%,$ADMIN_PASSWORD,g;
    s,%ADMIN_TENANT_NAME%,$ADMIN_TENANT_NAME,g;
" -i $TEMPEST_CONF

echo "Created tempest configuration file:"
cat $TEMPEST_CONF

echo "\n"
echo "**************************************************"
echo "Finished Configuring Tempest"
echo "**************************************************"
