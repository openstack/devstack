#!/bin/bash
# make_pxe.sh - Create a PXE boot environment
#
# make_pxe.sh destdir
#
# Assumes syslinux is installed
# Configues PXE for Ubuntu Natty and FreeDOS

UBUNTU_MIRROR=http://archive.ubuntu.com/ubuntu/dists/natty/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64

DEST_DIR=${1:-/tmp/tftpboot}
OPWD=`pwd`

DEFAULT=$DEST_DIR/pxelinux.cfg/default
cat >$DEFAULT <<EOF
default menu.c32
#display pxelinux.cfg/menu.txt
prompt 0
#timeout 0

MENU TITLE PXE Boot Menu

EOF

MENU=$DEST_DIR/pxelinux.cfg/menu.txt
cat >$MENU <<EOF
PXE Boot Menu

EOF

mkdir -p $DEST_DIR/pxelinux.cfg
cd $DEST_DIR
cp -p /usr/lib/syslinux/memdisk $DEST_DIR
cp -p /usr/lib/syslinux/pxelinux.0 $DEST_DIR

# Get Ubuntu netboot
mkdir -p $DEST_DIR/ubuntu
cd $DEST_DIR/ubuntu
wget -N --quiet $UBUNTU_MIRROR/linux
wget -N --quiet $UBUNTU_MIRROR/initrd.gz
cat >>$DEFAULT <<EOF

LABEL ubuntu
	MENU LABEL Ubuntu Natty
	KERNEL ubuntu/linux
	APPEND initrd=ubuntu/initrd.gz
EOF
cat >>$MENU <<EOF
ubuntu - Ubuntu Natty
EOF

# Get FreeDOS
mkdir -p $DEST_DIR/freedos
cd $DEST_DIR/freedos
wget -N --quiet http://www.fdos.org/bootdisks/autogen/FDSTD.288.gz
gunzip -f FDSTD.288.gz
cat >>$DEFAULT <<EOF

LABEL freedos
	MENU LABEL ^FreeDOS bootdisk
	KERNEL memdisk
	APPEND initrd=freedos/FDSTD.288
EOF
cat >>$MENU <<EOF
freedos - FreeDOS
EOF
