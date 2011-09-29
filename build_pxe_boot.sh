#!/bin/bash
# build_pxe_boot.sh - Create a PXE boot environment
#
# build_pxe_boot.sh [-k kernel-version] destdir
#
# Assumes syslinux is installed
# Assumes devstack files are in `pwd`/pxe
# Only needs to run as root if the destdir permissions require it

UBUNTU_MIRROR=http://archive.ubuntu.com/ubuntu/dists/natty/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64

MEMTEST_VER=4.10
MEMTEST_BIN=memtest86+-${MEMTEST_VER}.bin
MEMTEST_URL=http://www.memtest.org/download/${MEMTEST_VER}/

KVER=`uname -r`
if [ "$1" = "-k" ]; then
    KVER=$2
    shift;shift
fi

DEST_DIR=${1:-/tmp}/tftpboot
OPWD=`pwd`
PROGDIR=`dirname $0`

mkdir -p $DEST_DIR/pxelinux.cfg
cd $DEST_DIR
for i in memdisk menu.c32 pxelinux.0; do
	cp -p /usr/lib/syslinux/$i $DEST_DIR
done

DEFAULT=$DEST_DIR/pxelinux.cfg/default
cat >$DEFAULT <<EOF
default menu.c32
prompt 0
timeout 0

MENU TITLE PXE Boot Menu

EOF

# Setup devstack boot
mkdir -p $DEST_DIR/ubuntu
if [ ! -d $OPWD/pxe ]; then
    mkdir -p $OPWD/pxe
fi
if [ ! -r $OPWD/pxe/vmlinuz-${KVER}-generic ]; then
    if [ ! -r /boot/vmlinuz-${KVER}-generic ]; then
        echo "No kernel found"
    else
        cp -p /boot/vmlinuz-${KVER}-generic $OPWD/pxe
    fi
fi
cp -p $OPWD/pxe/vmlinuz-${KVER}-generic $DEST_DIR/ubuntu
if [ ! -r $OPWD/pxe/stack-initrd.gz ]; then
    $PROGDIR/build_pxe_ramdisk.sh $OPWD/pxe/stack-initrd.gz
fi
cp -p $OPWD/pxe/stack-initrd.gz $DEST_DIR/ubuntu
cat >>$DEFAULT <<EOF

LABEL devstack
    MENU LABEL ^devstack
    MENU DEFAULT
    KERNEL ubuntu/vmlinuz-$KVER-generic
    APPEND initrd=ubuntu/stack-initrd.gz ramdisk_size=2109600 root=/dev/ram0
EOF

# Get Ubuntu
if [ -d $OPWD/pxe ]; then
    cp -p $OPWD/pxe/natty-min-initrd.gz $DEST_DIR/ubuntu
fi
cat >>$DEFAULT <<EOF

LABEL ubuntu
    MENU LABEL ^Ubuntu Natty
    KERNEL ubuntu/vmlinuz-$KVER-generic
    APPEND initrd=ubuntu/natty-base-initrd.gz ramdisk_size=419600 root=/dev/ram0
EOF

# Get Memtest
cd $DEST_DIR
if [ ! -r $MEMTEST_BIN ]; then
    wget -N --quiet ${MEMTEST_URL}/${MEMTEST_BIN}.gz
    gunzip $MEMTEST_BIN
fi
cat >>$DEFAULT <<EOF

LABEL memtest
    MENU LABEL ^Memtest86+
    KERNEL $MEMTEST_BIN
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

# Local disk boot
cat >>$DEFAULT <<EOF

LABEL local
    MENU LABEL ^Local disk
    MENU DEFAULT
    LOCALBOOT 0
EOF
