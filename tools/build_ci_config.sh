#!/usr/bin/env bash
#
# build_ci_config.sh - Build a config.ini for openstack-integration-tests
#                      (https://github.com/openstack/openstack-integration-tests)

function usage {
    echo "$0 - Build config.ini for openstack-integration-tests"
    echo ""
    echo "Usage: $0 configdir"
    exit 1
}

if [ ! "$#" -eq "1" ]; then
    usage
fi

CONFIG_DIR=$1
CONFIG_CONF=$CONFIG_DIR/storm.conf
CONFIG_INI=$CONFIG_DIR/config.ini

# Clean up any resources that may be in use
cleanup() {
    set +o errexit

    # Mop up temporary files
    if [ -n "$CONFIG_CONF_TMP" -a -e "$CONFIG_CONF_TMP" ]; then
        rm -f $CONFIG_CONF_TMP
    fi
    if [ -n "$CONFIG_INI_TMP" -a -e "$CONFIG_INI_TMP" ]; then
        rm -f $CONFIG_INI_TMP
    fi

    # Kill ourselves to signal any calling process
    trap 2; kill -2 $$
}

trap cleanup SIGHUP SIGINT SIGTERM SIGQUIT EXIT

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=`cd $TOOLS_DIR/..; pwd`

# Abort if localrc is not set
if [ ! -e $TOP_DIR/localrc ]; then
    echo "You must have a localrc with ALL necessary passwords and configuration defined before proceeding."
    echo "See stack.sh for required passwords."
    exit 1
fi

# Source params
source ./stackrc

# Where Openstack code lives
DEST=${DEST:-/opt/stack}

DIST_NAME=${DIST_NAME:-oneiric}

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

# Create storm.conf

CONFIG_CONF_TMP=$(mktemp $CONFIG_CONF.XXXXXX)
    cat >$CONFIG_CONF_TMP <<EOF
[nova]
auth_url=http://$HOST_IP:5000/v2.0/tokens
user=admin
api_key=$ADMIN_PASSWORD
tenant_name=admin
ssh_timeout=300
build_interval=10
build_timeout=600

[environment]
image_ref=3
image_ref_alt=4
flavor_ref=1
flavor_ref_alt=2
create_image_enabled=true
resize_available=true
authentication=keystone_v2
EOF
mv $CONFIG_CONF_TMP $CONFIG_CONF
CONFIG_CONF_TMP=""

# Create config.ini

CONFIG_INI_TMP=$(mktemp $CONFIG_INI.XXXXXX)
if [ "$UPLOAD_LEGACY_TTY" ]; then
    cat >$CONFIG_INI_TMP <<EOF
[environment]
aki_location = $DEST/devstack/files/images/aki-tty/image
ari_location = $DEST/devstack/files/images/ari-tty/image
ami_location = $DEST/devstack/files/images/ami-tty/image
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
aki_location = $DEST/openstack-integration-tests/include/sample_vm/$DIST_NAME-server-cloudimg-amd64-vmlinuz-virtual
#ari_location = $DEST/openstack-integration-tests/include/sample_vm/$DIST_NAME-server-cloudimg-amd64-loader
ami_location = $DEST/openstack-integration-tests/include/sample_vm/$DIST_NAME-server-cloudimg-amd64.img
image_ref = 2
image_ref_alt = 2
flavor_ref = 1
flavor_ref_alt = 2

[glance]
host = $GLANCE_HOST
apiver = v1
port = $GLANCE_PORT
image_id = 1
image_id_alt = 1
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
tenant_id = 1

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
