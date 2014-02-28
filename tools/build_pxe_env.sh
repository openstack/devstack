#!/bin/bash -e

# **build_pxe_env.sh**

# Create a PXE boot environment
#
# build_pxe_env.sh destdir
#
# Requires Ubuntu Oneiric
#
# Only needs to run as root if the destdir permissions require it

dpkg -l syslinux || apt-get install -y syslinux

DEST_DIR=${1:-/tmp}/tftpboot
PXEDIR=${PXEDIR:-/opt/ramstack/pxe}
PROGDIR=`dirname $0`

# Clean up any resources that may be in use
function cleanup {
    set +o errexit

    # Mop up temporary files
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

mkdir -p $DEST_DIR/pxelinux.cfg
cd $DEST_DIR
for i in memdisk menu.c32 pxelinux.0; do
    cp -pu /usr/lib/syslinux/$i $DEST_DIR
done

CFG=$DEST_DIR/pxelinux.cfg/default
cat >$CFG <<EOF
default menu.c32
prompt 0
timeout 0

MENU TITLE devstack PXE Boot Menu

EOF

# Setup devstack boot
mkdir -p $DEST_DIR/ubuntu
if [ ! -d $PXEDIR ]; then
    mkdir -p $PXEDIR
fi

# Get image into place
if [ ! -r $PXEDIR/stack-initrd.img ]; then
    cd $TOP_DIR
    $PROGDIR/build_ramdisk.sh $PXEDIR/stack-initrd.img
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
    KERNEL ubuntu/vmlinuz-$KVER
    APPEND initrd=ubuntu/stack-initrd.gz ramdisk_size=2109600 root=/dev/ram0
EOF

# Get Ubuntu
if [ -d $PXEDIR -a -r $PXEDIR/natty-base-initrd.gz ]; then
    cp -pu $PXEDIR/natty-base-initrd.gz $DEST_DIR/ubuntu
    cat >>$CFG <<EOF

LABEL ubuntu
    MENU LABEL ^Ubuntu Natty
    KERNEL ubuntu/vmlinuz-$KVER
    APPEND initrd=ubuntu/natty-base-initrd.gz ramdisk_size=419600 root=/dev/ram0
EOF
fi

# Local disk boot
cat >>$CFG <<EOF

LABEL local
    MENU LABEL ^Local disk
    LOCALBOOT 0
EOF

trap cleanup SIGHUP SIGINT SIGTERM SIGQUIT EXIT
