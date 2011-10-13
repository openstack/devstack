#!/bin/bash -e
# build_usb_boot.sh - Create a syslinux boot environment
#
# build_usb_boot.sh [-k kernel-version] destdev
#
# Assumes syslinux is installed
# Needs to run as root

KVER=`uname -r`
if [ "$1" = "-k" ]; then
    KVER=$2
    shift;shift
fi

DEST_DIR=${1:-/tmp/syslinux-boot}
PXEDIR=${PXEDIR:-/var/cache/devstack/pxe}
OPWD=`pwd`
PROGDIR=`dirname $0`

if [ -b $DEST_DIR ]; then
    # We have a block device, install syslinux and mount it
    DEST_DEV=$DEST_DIR
    DEST_DIR=`mktemp -d mntXXXXXX`

    # Install syslinux on the device
    syslinux --install --directory syslinux $DEST_DEV

    mount $DEST_DEV $DEST_DIR
else
    # We have a directory (for sanity checking output)
	DEST_DEV=""
	if [ ! -d $DEST_DIR/syslinux ]; then
	    mkdir -p $DEST_DIR/syslinux
	fi
fi

# Get some more stuff from syslinux
for i in memdisk menu.c32; do
	cp -p /usr/lib/syslinux/$i $DEST_DIR/syslinux
done

CFG=$DEST_DIR/syslinux/syslinux.cfg
cat >$CFG <<EOF
default /syslinux/menu.c32
prompt 0
timeout 0

MENU TITLE Boot Menu

EOF

# Setup devstack boot
mkdir -p $DEST_DIR/ubuntu
if [ ! -d $PXEDIR ]; then
    mkdir -p $PXEDIR
fi
if [ ! -r $PXEDIR/vmlinuz-${KVER} ]; then
    sudo chmod 644 /boot/vmlinuz-${KVER}
    if [ ! -r /boot/vmlinuz-${KVER} ]; then
        echo "No kernel found"
    else
        cp -p /boot/vmlinuz-${KVER} $PXEDIR
    fi
fi
cp -p $PXEDIR/vmlinuz-${KVER} $DEST_DIR/ubuntu
if [ ! -r $PXEDIR/stack-initrd.gz ]; then
    cd $OPWD
    sudo $PROGDIR/build_ramdisk.sh $PXEDIR/stack-initrd.gz
fi
cp -p $PXEDIR/stack-initrd.gz $DEST_DIR/ubuntu
cat >>$CFG <<EOF

LABEL devstack
    MENU LABEL ^devstack
    MENU DEFAULT
    KERNEL /ubuntu/vmlinuz-$KVER
    APPEND initrd=/ubuntu/stack-initrd.gz ramdisk_size=2109600 root=/dev/ram0
EOF

# Get Ubuntu
if [ -d $PXEDIR -a -r $PXEDIR/natty-base-initrd.gz ]; then
    cp -p $PXEDIR/natty-base-initrd.gz $DEST_DIR/ubuntu
    cat >>$CFG <<EOF

LABEL ubuntu
    MENU LABEL ^Ubuntu Natty
    KERNEL /ubuntu/vmlinuz-$KVER
    APPEND initrd=/ubuntu/natty-base-initrd.gz ramdisk_size=419600 root=/dev/ram0
EOF
fi

# Local disk boot
cat >>$CFG <<EOF

LABEL local
    MENU LABEL ^Local disk
    LOCALBOOT 0
EOF

if [ -n "$DEST_DEV" ]; then
    umount $DEST_DIR
    rmdir $DEST_DIR
fi
