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

# Exit on errors
set -o errexit
# Echo commands
set -o xtrace

# This directory
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Include onexit commands
. $TOP_DIR/scripts/on_exit.sh

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

# Copy prepare_guest.sh to VM
mkdir -p $STAGING_DIR/opt/stack/
cp $TOP_DIR/prepare_guest.sh $STAGING_DIR/opt/stack/prepare_guest.sh

# backup rc.local
cp $STAGING_DIR/etc/rc.local $STAGING_DIR/etc/rc.local.preparebackup

# run prepare_guest.sh on boot
cat <<EOF >$STAGING_DIR/etc/rc.local
GUEST_PASSWORD=$GUEST_PASSWORD STAGING_DIR=/ DO_TGZ=0 bash /opt/stack/prepare_guest.sh > /opt/stack/prepare_guest.log 2>&1
EOF
