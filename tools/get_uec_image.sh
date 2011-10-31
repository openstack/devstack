#!/bin/bash
# get_uec_image.sh - Prepare Ubuntu images in various formats
#
# Supported formats: qcow (kvm), vmdk (vmserver), vdi (vbox), vhd (vpc), raw
#
# Required to run as root

CACHEDIR=${CACHEDIR:-/var/cache/devstack}
FORMAT=${FORMAT:-qcow2}
ROOTSIZE=${ROOTSIZE:-2000}
MIN_PKGS=${MIN_PKGS:-"apt-utils gpgv openssh-server"}

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=`cd $TOOLS_DIR/..; pwd`

usage() {
    echo "Usage: $0 - Prepare Ubuntu images"
    echo ""
    echo "$0 [-f format] [-r rootsize] release imagefile"
    echo ""
    echo "-f format - image format: qcow2 (default), vmdk, vdi, vhd, xen, raw, fs"
    echo "-r size   - root fs size in MB (min 2000MB)"
    echo "release   - Ubuntu release: jaunty - oneric"
    echo "imagefile - output image file"
    exit 1
}

while getopts f:hmr: c; do
    case $c in
        f)  FORMAT=$OPTARG
            ;;
        h)  usage
            ;;
        m)  MINIMAL=1
            ;;
        r)  ROOTSIZE=$OPTARG
            if [[ $ROOTSIZE < 2000 ]]; then
                echo "root size must be greater than 2000MB"
                exit 1
            fi
            ;;
    esac
done
shift `expr $OPTIND - 1`

if [ ! "$#" -eq "2" ]; then
    usage
fi

# Default args
DIST_NAME=$1
IMG_FILE=$2

case $FORMAT in
    kvm|qcow2)  FORMAT=qcow2
                QFORMAT=qcow2
                ;;
    vmserver|vmdk)
                FORMAT=vmdk
                QFORMAT=vmdk
                ;;
    vbox|vdi)   FORMAT=vdi
                QFORMAT=vdi
                ;;
    vhd|vpc)    FORMAT=vhd
                QFORMAT=vpc
                ;;
    xen)        FORMAT=raw
                QFORMAT=raw
                ;;
    raw)        FORMAT=raw
                QFORMAT=raw
                ;;
    *)          echo "Unknown format: $FORMAT"
                usage
esac

case $DIST_NAME in
    oneiric)    ;;
    natty)      ;;
    maverick)   ;;
    lucid)      ;;
    karmic)     ;;
    jaunty)     ;;
    *)          echo "Unknown release: $DIST_NAME"
                usage
                ;;
esac

# Set up nbd
modprobe nbd max_part=63
NBD=${NBD:-/dev/nbd9}
NBD_DEV=`basename $NBD`

# Prepare the base image

# Get the UEC image
UEC_NAME=$DIST_NAME-server-cloudimg-amd64
if [ ! -e $CACHEDIR/$UEC_NAME-disk1.img ]; then
    (cd $CACHEDIR && wget -N http://uec-images.ubuntu.com/$DIST_NAME/current/$UEC_NAME-disk1.img)


    # Connect to nbd and wait till it is ready
    qemu-nbd -d $NBD
    qemu-nbd -c $NBD $CACHEDIR/$UEC_NAME-disk1.img
    if ! timeout 60 sh -c "while ! [ -e /sys/block/$NBD_DEV/pid ]; do sleep 1; done"; then
        echo "Couldn't connect $NBD"
        exit 1
    fi
    MNTDIR=`mktemp -d mntXXXXXXXX`
    mount -t ext4 ${NBD}p1 $MNTDIR

    # Install our required packages
    cp -p $TOP_DIR/files/sources.list $MNTDIR/etc/apt/sources.list
    sed -e "s,%DIST%,$DIST_NAME,g" -i $MNTDIR/etc/apt/sources.list
    cp -p /etc/resolv.conf $MNTDIR/etc/resolv.conf
    chroot $MNTDIR apt-get update
    chroot $MNTDIR apt-get install -y $MIN_PKGS
    rm -f $MNTDIR/etc/resolv.conf

    umount $MNTDIR
    rmdir $MNTDIR
    qemu-nbd -d $NBD
fi

if [ "$FORMAT" = "qcow2" ]; then
    # Just copy image
    cp -p $CACHEDIR/$UEC_NAME-disk1.img $IMG_FILE
else
    # Convert image
    qemu-img convert -O $QFORMAT $CACHEDIR/$UEC_NAME-disk1.img $IMG_FILE
fi

# Resize the image if necessary
if [ $ROOTSIZE -gt 2000 ]; then
    # Resize the container
    qemu-img resize $IMG_FILE +$((ROOTSIZE - 2000))M
fi

# Connect to nbd and wait till it is ready
qemu-nbd -c $NBD $IMG_FILE
if ! timeout 60 sh -c "while ! [ -e /sys/block/$NBD_DEV/pid ]; do sleep 1; done"; then
echo "Couldn't connect $NBD"
    exit 1
fi

# Resize partition 1 to full size of the disk image
echo "d
n
p
1
2

t
83
a
1
w
" | fdisk $NBD
fsck -t ext4 -f ${NBD}p1
resize2fs ${NBD}p1

qemu-nbd -d $NBD
