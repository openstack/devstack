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

NOVA_SOURCE_DIR=$DEST/nova
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
# We ignore ramdisk and kernel images, look for the default image
# DEFAULT_IMAGE_NAME. If not found, we set the IMAGE_UUID to the
# first image returned and set IMAGE_UUID_ALT to the second,
# if there is more than one returned...
# ... Also ensure we only take active images, so we don't get snapshots in process
IMAGE_LINES=`glance image-list`
IFS="$(echo -e "\n\r")"
IMAGES=""
for line in $IMAGE_LINES; do
    if [ -z $DEFAULT_IMAGE_NAME ]; then
        IMAGES="$IMAGES `echo $line | grep -v "^\(ID\|+--\)" | grep -v "\(aki\|ari\)" | grep 'active' | cut -d' ' -f2`"
    else
        IMAGES="$IMAGES `echo $line | grep -v "^\(ID\|+--\)" | grep -v "\(aki\|ari\)" | grep 'active' | grep "$DEFAULT_IMAGE_NAME" | cut -d' ' -f2`"
    fi
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

COMPUTE_ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
COMPUTE_ADMIN_PASSWORD=${ADMIN_PASSWORD:-secrete}
COMPUTE_ADMIN_TENANT_NAME=${ADMIN_TENANT:-admin}

IDENTITY_ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
IDENTITY_ADMIN_PASSWORD=${ADMIN_PASSWORD:-secrete}
IDENTITY_ADMIN_TENANT_NAME=${ADMIN_TENANT:-admin}

IDENTITY_USE_SSL=${IDENTITY_USE_SSL:-False}
IDENTITY_HOST=${IDENTITY_HOST:-127.0.0.1}
IDENTITY_PORT=${IDENTITY_PORT:-5000}
IDENTITY_API_VERSION="v2.0" # Note: need v for now...
# TODO(jaypipes): This is dumb and needs to be removed
# from the Tempest configuration file entirely...
IDENTITY_PATH=${IDENTITY_PATH:-tokens}
IDENTITY_STRATEGY=${IDENTITY_STRATEGY:-keystone}
IDENTITY_CATALOG_TYPE=identity

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

# Check Nova for existing flavors and, if set, look for the
# DEFAULT_INSTANCE_TYPE and use that. Otherwise, just use the first flavor.
FLAVOR_LINES=`nova flavor-list`
IFS="$(echo -e "\n\r")"
FLAVORS=""
for line in $FLAVOR_LINES; do
    if [ -z $DEFAULT_INSTANCE_TYPE ]; then
        FLAVORS="$FLAVORS `echo $line | grep -v "^\(|\s*ID\|+--\)" | cut -d' ' -f2`"
    else
        FLAVORS="$FLAVORS `echo $line | grep -v "^\(|\s*ID\|+--\)" | grep "$DEFAULT_INSTANCE_TYPE" | cut -d' ' -f2`"
    fi
done
IFS=" "
FLAVORS=($FLAVORS)
NUM_FLAVORS=${#FLAVORS[*]}
echo "Found $NUM_FLAVORS flavors"
if [[ $NUM_FLAVORS -eq 0 ]]; then
    echo "Found no valid flavors to use!"
    exit 1
fi
FLAVOR_REF=${FLAVORS[0]}
FLAVOR_REF_ALT=$FLAVOR_REF
if [[ $NUM_FLAVORS -gt 1 ]]; then
    FLAVOR_REF_ALT=${FLAVORS[1]}
fi

# Do any of the following need to be configurable?
COMPUTE_CATALOG_TYPE=compute
COMPUTE_CREATE_IMAGE_ENABLED=True
COMPUTE_ALLOW_TENANT_ISOLATION=True
COMPUTE_ALLOW_TENANT_REUSE=True
COMPUTE_RESIZE_AVAILABLE=False
COMPUTE_CHANGE_PASSWORD_AVAILABLE=False  # not supported with QEMU...
COMPUTE_LOG_LEVEL=ERROR
BUILD_INTERVAL=3
BUILD_TIMEOUT=400
COMPUTE_BUILD_INTERVAL=3
COMPUTE_BUILD_TIMEOUT=400
VOLUME_BUILD_INTERVAL=3
VOLUME_BUILD_TIMEOUT=300
RUN_SSH=True
# Check for DEFAULT_INSTANCE_USER and try to connect with that account
SSH_USER=${DEFAULT_INSTANCE_USER:-$OS_USERNAME}
NETWORK_FOR_SSH=private
IP_VERSION_FOR_SSH=4
SSH_TIMEOUT=4
# Whitebox testing configuration for Compute...
COMPUTE_WHITEBOX_ENABLED=True
COMPUTE_SOURCE_DIR=$NOVA_SOURCE_DIR
COMPUTE_BIN_DIR=/usr/bin/nova
COMPUTE_CONFIG_PATH=/etc/nova/nova.conf
# TODO(jaypipes): Create the key file here... right now, no whitebox
# tests actually use a key.
COMPUTE_PATH_TO_PRIVATE_KEY=$TEMPEST_DIR/id_rsa
COMPUTE_DB_URI=mysql://root:$MYSQL_PASSWORD@localhost/nova

# Image test configuration options...
IMAGE_HOST=${IMAGE_HOST:-127.0.0.1}
IMAGE_PORT=${IMAGE_PORT:-9292}
IMAGE_API_VERSION=1
IMAGE_CATALOG_TYPE=image

# Network API test configuration
NETWORK_CATALOG_TYPE=network
NETWORK_API_VERSION=2.0

# Volume API test configuration
VOLUME_CATALOG_TYPE=volume

sed -e "
    s,%IDENTITY_USE_SSL%,$IDENTITY_USE_SSL,g;
    s,%IDENTITY_HOST%,$IDENTITY_HOST,g;
    s,%IDENTITY_PORT%,$IDENTITY_PORT,g;
    s,%IDENTITY_API_VERSION%,$IDENTITY_API_VERSION,g;
    s,%IDENTITY_PATH%,$IDENTITY_PATH,g;
    s,%IDENTITY_STRATEGY%,$IDENTITY_STRATEGY,g;
    s,%IDENTITY_CATALOG_TYPE%,$IDENTITY_CATALOG_TYPE,g;
    s,%USERNAME%,$OS_USERNAME,g;
    s,%PASSWORD%,$OS_PASSWORD,g;
    s,%TENANT_NAME%,$OS_TENANT_NAME,g;
    s,%ALT_USERNAME%,$ALT_USERNAME,g;
    s,%ALT_PASSWORD%,$ALT_PASSWORD,g;
    s,%ALT_TENANT_NAME%,$ALT_TENANT_NAME,g;
    s,%COMPUTE_CATALOG_TYPE%,$COMPUTE_CATALOG_TYPE,g;
    s,%COMPUTE_ALLOW_TENANT_ISOLATION%,$COMPUTE_ALLOW_TENANT_ISOLATION,g;
    s,%COMPUTE_ALLOW_TENANT_REUSE%,$COMPUTE_ALLOW_TENANT_REUSE,g;
    s,%COMPUTE_CREATE_IMAGE_ENABLED%,$COMPUTE_CREATE_IMAGE_ENABLED,g;
    s,%COMPUTE_RESIZE_AVAILABLE%,$COMPUTE_RESIZE_AVAILABLE,g;
    s,%COMPUTE_CHANGE_PASSWORD_AVAILABLE%,$COMPUTE_CHANGE_PASSWORD_AVAILABLE,g;
    s,%COMPUTE_WHITEBOX_ENABLED%,$COMPUTE_WHITEBOX_ENABLED,g;
    s,%COMPUTE_LOG_LEVEL%,$COMPUTE_LOG_LEVEL,g;
    s,%BUILD_INTERVAL%,$BUILD_INTERVAL,g;
    s,%BUILD_TIMEOUT%,$BUILD_TIMEOUT,g;
    s,%COMPUTE_BUILD_INTERVAL%,$COMPUTE_BUILD_INTERVAL,g;
    s,%COMPUTE_BUILD_TIMEOUT%,$COMPUTE_BUILD_TIMEOUT,g;
    s,%RUN_SSH%,$RUN_SSH,g;
    s,%SSH_USER%,$SSH_USER,g;
    s,%NETWORK_FOR_SSH%,$NETWORK_FOR_SSH,g;
    s,%IP_VERSION_FOR_SSH%,$IP_VERSION_FOR_SSH,g;
    s,%SSH_TIMEOUT%,$SSH_TIMEOUT,g;
    s,%IMAGE_ID%,$IMAGE_UUID,g;
    s,%IMAGE_ID_ALT%,$IMAGE_UUID_ALT,g;
    s,%FLAVOR_REF%,$FLAVOR_REF,g;
    s,%FLAVOR_REF_ALT%,$FLAVOR_REF_ALT,g;
    s,%COMPUTE_CONFIG_PATH%,$COMPUTE_CONFIG_PATH,g;
    s,%COMPUTE_SOURCE_DIR%,$COMPUTE_SOURCE_DIR,g;
    s,%COMPUTE_BIN_DIR%,$COMPUTE_BIN_DIR,g;
    s,%COMPUTE_PATH_TO_PRIVATE_KEY%,$COMPUTE_PATH_TO_PRIVATE_KEY,g;
    s,%COMPUTE_DB_URI%,$COMPUTE_DB_URI,g;
    s,%IMAGE_HOST%,$IMAGE_HOST,g;
    s,%IMAGE_PORT%,$IMAGE_PORT,g;
    s,%IMAGE_API_VERSION%,$IMAGE_API_VERSION,g;
    s,%IMAGE_CATALOG_TYPE%,$IMAGE_CATALOG_TYPE,g;
    s,%COMPUTE_ADMIN_USERNAME%,$COMPUTE_ADMIN_USERNAME,g;
    s,%COMPUTE_ADMIN_PASSWORD%,$COMPUTE_ADMIN_PASSWORD,g;
    s,%COMPUTE_ADMIN_TENANT_NAME%,$COMPUTE_ADMIN_TENANT_NAME,g;
    s,%IDENTITY_ADMIN_USERNAME%,$IDENTITY_ADMIN_USERNAME,g;
    s,%IDENTITY_ADMIN_PASSWORD%,$IDENTITY_ADMIN_PASSWORD,g;
    s,%IDENTITY_ADMIN_TENANT_NAME%,$IDENTITY_ADMIN_TENANT_NAME,g;
    s,%NETWORK_CATALOG_TYPE%,$NETWORK_CATALOG_TYPE,g;
    s,%NETWORK_API_VERSION%,$NETWORK_API_VERSION,g;
    s,%VOLUME_CATALOG_TYPE%,$VOLUME_CATALOG_TYPE,g;
    s,%VOLUME_BUILD_INTERVAL%,$VOLUME_BUILD_INTERVAL,g;
    s,%VOLUME_BUILD_TIMEOUT%,$VOLUME_BUILD_TIMEOUT,g;
" -i $TEMPEST_CONF

echo "Created tempest configuration file:"
cat $TEMPEST_CONF

echo "\n"
echo "**************************************************"
echo "Finished Configuring Tempest"
echo "**************************************************"
