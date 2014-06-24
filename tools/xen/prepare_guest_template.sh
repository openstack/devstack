#!/bin/bash

# This script is run by install_os_domU.sh
#
# Parameters:
# - $GUEST_NAME - hostname for the DomU VM
#
# It modifies the ubuntu image created by install_os_domU.sh
#
# This script is responsible for cusomtizing the fresh ubuntu
# image so on boot it runs the prepare_guest.sh script
# that modifies the VM so it is ready to run stack.sh.
# It does this by mounting the disk image of the VM.
#
# The resultant image is started by install_os_domU.sh,
# and once the VM has shutdown, build_xva.sh is run

set -o errexit
set -o nounset
set -o xtrace

# This directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Source lower level functions
. $TOP_DIR/../../functions

# Include onexit commands
. $TOP_DIR/scripts/on_exit.sh

# xapi functions
. $TOP_DIR/functions

# Determine what system we are running on.
# Might not be XenServer if we're using xenserver-core
GetDistro

# Source params - override xenrc params in your localrc to suite your taste
source xenrc

#
# Parameters
#
GUEST_NAME="$1"

# Mount the VDI
STAGING_DIR=$($TOP_DIR/scripts/manage-vdi open $GUEST_NAME 0 1 | grep -o "/tmp/tmp.[[:alnum:]]*")
add_on_exit "$TOP_DIR/scripts/manage-vdi close $GUEST_NAME 0 1"

# Make sure we have a stage
if [ ! -d $STAGING_DIR/etc ]; then
    echo "Stage is not properly set up!"
    exit 1
fi

# Copy XenServer tools deb into the VM
ISO_DIR="/opt/xensource/packages/iso"
XS_TOOLS_FILE_NAME="xs-tools.deb"
XS_TOOLS_PATH="/root/$XS_TOOLS_FILE_NAME"
if [ -e "$ISO_DIR" ]; then
    TOOLS_ISO=$(ls -1 $ISO_DIR/xs-tools-*.iso | head -1)
    TMP_DIR=/tmp/temp.$RANDOM
    mkdir -p $TMP_DIR
    mount -o loop $TOOLS_ISO $TMP_DIR
    DEB_FILE=$(ls $TMP_DIR/Linux/*amd64.deb)
    echo "Copying XenServer tools into VM from: $DEB_FILE"
    cp $DEB_FILE "${STAGING_DIR}${XS_TOOLS_PATH}"
    umount $TMP_DIR
    rm -rf $TMP_DIR
else
    echo "WARNING: no XenServer tools found, falling back to 5.6 tools"
    TOOLS_URL="https://github.com/downloads/citrix-openstack/warehouse/xe-guest-utilities_5.6.100-651_amd64.deb"
    curl --no-sessionid -L -o "$XS_TOOLS_FILE_NAME" $TOOLS_URL
    cp $XS_TOOLS_FILE_NAME "${STAGING_DIR}${XS_TOOLS_PATH}"
    rm -rf $XS_TOOLS_FILE_NAME
fi

# Copy prepare_guest.sh to VM
mkdir -p $STAGING_DIR/opt/stack/
cp $TOP_DIR/prepare_guest.sh $STAGING_DIR/opt/stack/prepare_guest.sh

# backup rc.local
cp $STAGING_DIR/etc/rc.local $STAGING_DIR/etc/rc.local.preparebackup

# run prepare_guest.sh on boot
cat <<EOF >$STAGING_DIR/etc/rc.local
#!/bin/sh -e
bash /opt/stack/prepare_guest.sh \\
    "$GUEST_PASSWORD" "$XS_TOOLS_PATH" "$STACK_USER" "$DOMZERO_USER" \\
    > /opt/stack/prepare_guest.log 2>&1
EOF

# Need to set barrier=0 to avoid a Xen bug
# https://bugs.launchpad.net/ubuntu/+source/linux/+bug/824089
sed -i -e 's/errors=/barrier=0,errors=/' $STAGING_DIR/etc/fstab
