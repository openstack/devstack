#!/bin/bash
# make_image.sh - Create Ubuntu images in various formats
#
# Supported formats: qcow (kvm), vmdk (vmserver), vdi (vbox), vhd (vpc), raw
#
# Requires sudo to root

ROOTSIZE=${ROOTSIZE:-8192}
SWAPSIZE=${SWAPSIZE:-1024}
MIN_PKGS=${MIN_PKGS:-"apt-utils gpgv openssh-server"}

usage() {
    echo "Usage: $0 - Create Ubuntu images"
    echo ""
    echo "$0 [-m] [-r rootsize] [-s swapsize] release format"
    echo "$0 -C [-m] release chrootdir"
    echo "$0 -I [-r rootsize] [-s swapsize] chrootdir format"
    echo ""
    echo "-C        - Create the initial chroot dir"
    echo "-I        - Create the final image from a chroot"
    echo "-m        - minimal installation"
    echo "-r size   - root fs size in MB"
    echo "-s size   - swap fs size in MB"
    echo "release   - Ubuntu release: jaunty - oneric"
    echo "format    - image format: qcow2, vmdk, vdi, vhd, xen, raw, fs"
    exit 1
}

while getopts CIhmr:s: c; do
    case $c in
        C)  CHROOTONLY=1
            ;;
        I)  IMAGEONLY=1
            ;;
        h)  usage
            ;;
        m)  MINIMAL=1
            ;;
        r)  ROOTSIZE=$OPTARG
            ;;
        s)  SWAPSIZE=$OPTARG
            ;;
    esac
done
shift `expr $OPTIND - 1`

if [ ! "$#" -eq "2" -o -n "$CHROOTONLY" -a -n "$IMAGEONLY" ]; then
    usage
fi

# Default args
RELEASE=$1
FORMAT=$2
CHROOTDIR=""

if [ -n "$CHROOTONLY" ]; then
    RELEASE=$1
    CHROOTDIR=$2
    FORMAT="pass"
fi

if [ -n "$IMAGEONLY" ]; then
    CHROOTDIR=$1
    FORMAT=$2
    RELEASE="pass"
fi

case $FORMAT in
    kvm|qcow2)  FORMAT=qcow2
                QFORMAT=qcow2
                HYPER=kvm
                ;;
    vmserver|vmdk)
                FORMAT=vmdk
                QFORMAT=vmdk
                HYPER=vmserver
                ;;
    vbox|vdi)   FORMAT=vdi
                QFORMAT=vdi
                HYPER=kvm
                ;;
    vhd|vpc)    FORMAT=vhd
                QFORMAT=vpc
                HYPER=kvm
                ;;
    xen)        FORMAT=raw
                QFORMAT=raw
                HYPER=xen
                ;;
    raw)        FORMAT=raw
                QFORMAT=raw
                HYPER=kvm
                ;;
    pass)       ;;
    *)          echo "Unknown format: $FORMAT"
                usage
esac

case $RELEASE in
    oneric)     ;;
    natty)      ;;
    maverick)   ;;
    lucid)      ;;
    karmic)     ;;
    jaunty)     ;;
    pass)       ;;
    *)          echo "Unknown release: $RELEASE"
                usage
                ;;
esac

# Install stuff if necessary
if [ -z `which vmbuilder` ]; then
    sudo apt-get install -y ubuntu-vm-builder
fi

if [ -n "$CHROOTONLY" ]; then
    # Build a chroot directory
    HYPER=kvm
    if [ "$MINIMAL" = 1 ]; then
        ARGS="--variant=minbase"
        for i in $MIN_PKGS; do
            ARGS="$ARGS --addpkg=$i"
        done
    fi
    sudo vmbuilder $HYPER ubuntu $ARGS \
      --suite $RELEASE \
      --only-chroot \
      --chroot-dir=$CHROOTDIR \
      --overwrite \
      --addpkg=$MIN_PKGS \

    sudo cp -p files/sources.list $CHROOTDIR/etc/apt/sources.list
    sudo chroot $CHROOTDIR apt-get update

    exit 0
fi

# Build the image
TMPDIR=tmp
TMPDISK=`mktemp imgXXXXXXXX`
SIZE=$[$ROOTSIZE+$SWAPSIZE+1]
dd if=/dev/null of=$TMPDISK bs=1M seek=$SIZE count=1

if [ -n "$IMAGEONLY" ]; then
    # Build image from chroot
    sudo vmbuilder $HYPER ubuntu $ARGS \
      --existing-chroot=$CHROOTDIR \
      --overwrite \
      --rootsize=$ROOTSIZE \
      --swapsize=$SWAPSIZE \
      --tmpfs - \
      --raw=$TMPDISK \

else
    # Do the whole shebang in one pass
        ARGS="--variant=minbase"
        for i in $MIN_PKGS; do
            ARGS="$ARGS --addpkg=$i"
        done
    sudo vmbuilder $HYPER ubuntu $ARGS \
      --suite $RELEASE \
      --overwrite \
      --rootsize=$ROOTSIZE \
      --swapsize=$SWAPSIZE \
      --tmpfs - \
      --raw=$TMPDISK \

fi

if [ "$FORMAT" = "raw" ]; then
    # Get image
    mv $TMPDISK $RELEASE.$FORMAT
else
    # Convert image
    qemu-img convert -O $QFORMAT $TMPDISK $RELEASE.$FORMAT
    rm $TMPDISK
fi
rm -rf ubuntu-$HYPER
