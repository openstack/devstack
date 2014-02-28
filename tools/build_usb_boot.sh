#!/bin/bash -e

# **build_usb_boot.sh**

# Create a syslinux boot environment
#
# build_usb_boot.sh destdev
#
# Assumes syslinux is installed
# Needs to run as root

DEST_DIR=${1:-/tmp/syslinux-boot}
PXEDIR=${PXEDIR:-/opt/ramstack/pxe}

# Clean up any resources that may be in use
function cleanup {
    set +o errexit

    # Mop up temporary files
    if [ -n "$DEST_DEV" ]; then
        umount $DEST_DIR
        rmdir $DEST_DIR
    fi
    if [ -n "$MNTDIR" -a -d "$MNTDIR" ]; then
        umount $MNTDIR
        rmdir $MNTDIR
    fi

    # Kill ourselves to signal any calling process
    trap 2; kill -2 $$
}

trap cleanup SIGHUP SIGINT SIGTERM SIGQUIT EXIT

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=`cd $TOOLS_DIR/..; pwd`

if [ -b $DEST_DIR ]; then
    # We have a block device, install syslinux and mount it
    DEST_DEV=$DEST_DIR
    DEST_DIR=`mktemp -d --tmpdir mntXXXXXX`
    mount $DEST_DEV $DEST_DIR

    if [ ! -d $DEST_DIR/syslinux ]; then
        mkdir -p $DEST_DIR/syslinux
    fi

    # Install syslinux on the device
    syslinux --install --directory syslinux $DEST_DEV
else
    # We have a directory (for sanity checking output)
    DEST_DEV=""
    if [ ! -d $DEST_DIR/syslinux ]; then
        mkdir -p $DEST_DIR/syslinux
    fi
fi

# Get some more stuff from syslinux
for i in memdisk menu.c32; do
    cp -pu /usr/lib/syslinux/$i $DEST_DIR/syslinux
done

CFG=$DEST_DIR/syslinux/syslinux.cfg
cat >$CFG <<EOF
default /syslinux/menu.c32
prompt 0
timeout 0

MENU TITLE devstack Boot Menu

EOF

# Setup devstack boot
mkdir -p $DEST_DIR/ubuntu
if [ ! -d $PXEDIR ]; then
    mkdir -p $PXEDIR
fi

# Get image into place
if [ ! -r $PXEDIR/stack-initrd.img ]; then
    cd $TOP_DIR
    $TOOLS_DIR/build_uec_ramdisk.sh $PXEDIR/stack-initrd.img
fi
if [ ! -r $PXEDIR/stack-initrd.gz ]; then
    gzip -1 -c $PXEDIR/stack-initrd.img >$PXEDIR/stack-initrd.gz
fi
cp -pu $PXEDIR/stack-initrd.gz $DEST_DIR/ubuntu

if [ ! -r $PXEDIR/vmlinuz-*-generic ]; then
    MNTDIR=`mktemp -d --tmpdir mntXXXXXXXX`
    mount -t ext4 -o loop $PXEDIR/stack-initrd.img $MNTDIR

    if [ ! -r $MNTDIR/boot/vmlinuz-*-generic ]; then
        echo "No kernel found"
        umount $MNTDIR
        rmdir $MNTDIR
        if [ -n "$DEST_DEV" ]; then
            umount $DEST_DIR
            rmdir $DEST_DIR
        fi
        exit 1
    else
        cp -pu $MNTDIR/boot/vmlinuz-*-generic $PXEDIR
    fi
    umount $MNTDIR
    rmdir $MNTDIR
fi

# Get generic kernel version
KNAME=`basename $PXEDIR/vmlinuz-*-generic`
KVER=${KNAME#vmlinuz-}
cp -pu $PXEDIR/vmlinuz-$KVER $DEST_DIR/ubuntu
cat >>$CFG <<EOF

LABEL devstack
    MENU LABEL ^devstack
    MENU DEFAULT
    KERNEL /ubuntu/vmlinuz-$KVER
    APPEND initrd=/ubuntu/stack-initrd.gz ramdisk_size=2109600 root=/dev/ram0
EOF

# Get Ubuntu
if [ -d $PXEDIR -a -r $PXEDIR/natty-base-initrd.gz ]; then
    cp -pu $PXEDIR/natty-base-initrd.gz $DEST_DIR/ubuntu
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

trap - SIGHUP SIGINT SIGTERM SIGQUIT EXIT
