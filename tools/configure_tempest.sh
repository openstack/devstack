#!/usr/bin/env bash
#
# configure_tempest.sh - Build a tempest configuration file from devstack

function usage {
    echo "$0 - Build tempest.conf"
    echo ""
    echo "Usage: $0 [configdir]"
    exit 1
}

if [ "$1" = "-h" ]; then
    usage
fi

# Clean up any resources that may be in use
cleanup() {
    set +o errexit

    # Mop up temporary files
    if [ -n "$CONFIG_INI_TMP" -a -e "$CONFIG_INI_TMP" ]; then
        rm -f $CONFIG_INI_TMP
    fi

    # Kill ourselves to signal any calling process
    trap 2; kill -2 $$
}

trap cleanup SIGHUP SIGINT SIGTERM SIGQUIT EXIT

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $TOOLS_DIR/..; pwd)

# Import common functions
. $TOP_DIR/functions

# Abort if localrc is not set
if [ ! -e $TOP_DIR/localrc ]; then
    echo "You must have a localrc with ALL necessary passwords and configuration defined before proceeding."
    echo "See stack.sh for required passwords."
    exit 1
fi

# Source params
source ./stackrc

# Set defaults not configured by stackrc
TENANT=${TENANT:-admin}
USERNAME=${USERNAME:-admin}
IDENTITY_HOST=${IDENTITY_HOST:-$HOST_IP}
IDENTITY_PORT=${IDENTITY_PORT:-5000}
IDENTITY_API_VERSION=${IDENTITY_API_VERSION:-2.0}

# Where Openstack code lives
DEST=${DEST:-/opt/stack}

TEMPEST_DIR=$DEST/tempest

CONFIG_DIR=${1:-$TEMPEST_DIR/etc}
CONFIG_INI=$CONFIG_DIR/config.ini
TEMPEST_CONF=$CONFIG_DIR/tempest.conf

if [ ! -f $DEST/.ramdisk ]; then
    # Process network configuration vars
    GUEST_NETWORK=${GUEST_NETWORK:-1}
    GUEST_RECREATE_NET=${GUEST_RECREATE_NET:-yes}

    GUEST_IP=${GUEST_IP:-192.168.$GUEST_NETWORK.50}
    GUEST_CIDR=${GUEST_CIDR:-$GUEST_IP/24}
    GUEST_NETMASK=${GUEST_NETMASK:-255.255.255.0}
    GUEST_GATEWAY=${GUEST_GATEWAY:-192.168.$GUEST_NETWORK.1}
    GUEST_MAC=${GUEST_MAC:-"02:16:3e:07:69:`printf '%02X' $GUEST_NETWORK`"}
    GUEST_RAM=${GUEST_RAM:-1524288}
    GUEST_CORES=${GUEST_CORES:-1}
fi

# Use the GUEST_IP unless an explicit IP is set by ``HOST_IP``
HOST_IP=${HOST_IP:-$GUEST_IP}
# Use the first IP if HOST_IP still is not set
if [ ! -n "$HOST_IP" ]; then
    HOST_IP=`LC_ALL=C /sbin/ifconfig  | grep -m 1 'inet addr:'| cut -d: -f2 | awk '{print $1}'`
fi

RABBIT_HOST=${RABBIT_HOST:-localhost}

# Glance connection info.  Note the port must be specified.
GLANCE_HOSTPORT=${GLANCE_HOSTPORT:-$HOST_IP:9292}
set `echo $GLANCE_HOSTPORT | tr ':' ' '`
GLANCE_HOST=$1
GLANCE_PORT=$2

# Set up downloaded images
# Defaults to use first image

IMAGE_DIR=""
IMAGE_NAME=""
for imagedir in $TOP_DIR/files/images/*; do
    KERNEL=""
    RAMDISK=""
    IMAGE=""
    IMAGE_RAMDISK=""
    KERNEL=$(for f in "$imagedir/"*-vmlinuz*; do
        [ -f "$f" ] && echo "$f" && break; done; true)
    [ -n "$KERNEL" ] && ln -sf $KERNEL $imagedir/kernel
    RAMDISK=$(for f in "$imagedir/"*-initrd*; do
        [ -f "$f" ] && echo "$f" && break; done; true)
    [ -n "$RAMDISK" ] && ln -sf $RAMDISK $imagedir/ramdisk && \
                         IMAGE_RAMDISK="ari_location = $imagedir/ramdisk"
    IMAGE=$(for f in "$imagedir/"*.img; do
        [ -f "$f" ] && echo "$f" && break; done; true)
    if [ -n "$IMAGE" ]; then
        ln -sf $IMAGE $imagedir/disk
        # Save the first image directory that contains a disk image link
        if [ -z "$IMAGE_DIR" ]; then
            IMAGE_DIR=$imagedir
            IMAGE_NAME=$(basename ${IMAGE%.img})
        fi
    fi
done
if [[ -n "$IMAGE_NAME" ]]; then
    # Get the image UUID
    IMAGE_UUID=$(nova image-list | grep " $IMAGE_NAME " | cut -d'|' -f2)
    # Strip spaces off
    IMAGE_UUID=$(echo $IMAGE_UUID)
fi

# Create tempest.conf from tempest.conf.tpl

if [[ ! -r $TEMPEST_CONF ]]; then
    cp $TEMPEST_CONF.tpl $TEMPEST_CONF
fi

IDENTITY_USE_SSL=${IDENTITY_USE_SSL:-False}
IDENTITY_PORT=${IDENTITY_PORT:-5000}
IDENTITY_API_VERSION={$IDENTITY_API_VERSION:-v2.0} # Note: need v for now...
# TODO(jaypipes): This is dumb and needs to be removed
# from the Tempest configuration file entirely...
IDENTITY_PATH=${IDENTITY_PATH:-tokens}
IDENTITY_STRATEGY=${IDENTITY_STRATEGY:-keystone}

# We use regular, non-admin users in Tempest for the USERNAME
# substitutions and use ADMIN_USERNAME et al for the admin stuff.
# OS_USERNAME et all should be defined in openrc.
OS_USERNAME=${OS_USERNAME:-demo}
OS_TENANT_NAME=${OS_TENANT_NAME:-demo}
OS_PASSWORD=${OS_PASSWORD:-secrete}

# TODO(jaypipes): Support multiple regular user accounts instead
# of using the same regular user account for the alternate user...
ALT_USERNAME=$OS_USERNAME
ALT_PASSWORD=$OS_PASSWORD
ALT_TENANT_NAME=$OS_TENANT_NAME

# TODO(jaypipes): Support multiple images instead of plopping
# the IMAGE_UUID into both the image_ref and image_ref_alt slots
IMAGE_UUID_ALT=$IMAGE_UUID

# TODO(jaypipes): Support configurable flavor refs here...
FLAVOR_REF=1
FLAVOR_REF_ALT=2

ADMIN_USERNAME={$ADMIN_USERNAME:-admin}
ADMIN_PASSWORD={$ADMIN_PASSWORD:-secrete}
ADMIN_TENANT_NAME={$ADMIN_TENANT:-admin}

# Do any of the following need to be configurable?
COMPUTE_CATALOG_TYPE=compute
COMPUTE_CREATE_IMAGE_ENABLED=True
COMPUTE_RESIZE_AVAILABLE=True
COMPUTE_LOG_LEVEL=ERROR

sed -e "
    s,%IDENTITY_USE_SSL%,$IDENTITY_USE_SSL,g;
    s,%IDENTITY_HOST%,$HOST_IP,g;
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
    s,%IMAGE_ID%,$IMAGE_UUID,g;
    s,%IMAGE_ID_ALT%,$IMAGE_UUID_ALT,g;
    s,%FLAVOR_REF%,$FLAVOR_REF,g;
    s,%FLAVOR_REF_ALT%,$FLAVOR_REF_ALT,g;
    s,%ADMIN_USERNAME%,$ADMIN_USERNAME,g;
    s,%ADMIN_PASSWORD%,$ADMIN_PASSWORD,g;
    s,%ADMIN_TENANT_NAME%,$ADMIN_TENANT_NAME,g;
" -i $TEMPEST_CONF

# Create config.ini

CONFIG_INI_TMP=$(mktemp $CONFIG_INI.XXXXXX)
if [ "$UPLOAD_LEGACY_TTY" ]; then
    cat >$CONFIG_INI_TMP <<EOF
[environment]
aki_location = $TOP_DIR/files/images/aki-tty/image
ari_location = $TOP_DIR/files/images/ari-tty/image
ami_location = $TOP_DIR/files/images/ami-tty/image
image_ref = 3
image_ref_alt = 3
flavor_ref = 1
flavor_ref_alt = 2

[glance]
host = $GLANCE_HOST
apiver = v1
port = $GLANCE_PORT
image_id = 3
image_id_alt = 3
tenant_id = 1
EOF
else
    cat >$CONFIG_INI_TMP <<EOF
[environment]
aki_location = $IMAGE_DIR/kernel
ami_location = $IMAGE_DIR/disk
$IMAGE_RAMDISK
image_ref = 2
image_ref_alt = 2
flavor_ref = 1
flavor_ref_alt = 2

[glance]
host = $GLANCE_HOST
apiver = v1
port = $GLANCE_PORT
image_id = 2
image_id_alt = 2
tenant_id = 1
EOF
fi

cat >>$CONFIG_INI_TMP <<EOF

[keystone]
service_host = $HOST_IP
service_port = 5000
apiver = v2.0
user = admin
password = $ADMIN_PASSWORD
tenant_name = admin

[nova]
host = $HOST_IP
port = 8774
apiver = v1.1
project = admin
user = admin
key = $ADMIN_PASSWORD
ssh_timeout = 300
build_timeout = 300
flavor_ref = 1
flavor_ref_alt = 2
multi_node = no

[rabbitmq]
host = $RABBIT_HOST
user = guest
password = $RABBIT_PASSWORD

[swift]
auth_host = $HOST_IP
auth_port = 443
auth_prefix = /auth/
auth_ssl = yes
account = system
username = root
password = password

EOF
mv $CONFIG_INI_TMP $CONFIG_INI
CONFIG_INI_TMP=""

trap - SIGHUP SIGINT SIGTERM SIGQUIT EXIT
