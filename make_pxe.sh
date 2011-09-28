#!/bin/bash
# make_pxe.sh - Create a PXE boot environment
#
# make_pxe.sh destdir
#
# Assumes syslinux is installed
# Configues PXE for Ubuntu Natty and FreeDOS

UBUNTU_MIRROR=http://archive.ubuntu.com/ubuntu/dists/natty/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64

MEMTEST_VER=4.10
MEMTEST_BIN=memtest86+-${MEMTEST_VER}.bin
MEMTEST_URL=http://www.memtest.org/download/${MEMTEST_VER}/

DEST_DIR=${1:-/tmp}/tftpboot
OPWD=`pwd`

mkdir -p $DEST_DIR/pxelinux.cfg
cd $DEST_DIR
for i in memdisk menu.c32 pxelinux.0; do
	cp -p /usr/lib/syslinux/$i $DEST_DIR
done

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

# Get Memtest
cd $DEST_DIR
if [ ! -r $MEMTEST_BIN ]; then
    wget -N --quiet ${MEMTEST_URL}/${MEMTEST_BIN}.gz
    gunzip $MEMTEST_BIN
fi
cat >>$DEFAULT <<EOF

LABEL memtest
    MENU LABEL Memtest86+
    KERNEL $MEMTEST_BIN
EOF
cat >>$MENU <<EOF
memtest - Memtest86+
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

# Local disk boot
cat >>$DEFAULT <<EOF

LABEL local
    MENU LABEL Local disk
    MENU DEFAULT
    LOCALBOOT 0
EOF
cat >>$MENU <<EOF
local - Local disk boot
EOF

