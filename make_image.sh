#!/bin/bash
# make_image.sh - Create Ubuntu images in various formats
#
# make_image.sh release format
#
# Supported formats: qcow (kvm), vmdk (vmserver), vdi (vbox), vhd (vpc), raw
#
# Requires sudo to root

ROOTSIZE=${ROOTSIZE:-8192}
SWAPSIZE=${SWAPSIZE:-1024}

usage() {
    echo "$0 - Create Ubuntu images"
    echo ""
    echo "$0 [-r rootsize] [-s swapsize] release format"
    exit 1
}

while getopts hm:r:s: c; do
    case $c in
        h)  usage
            ;;
        m)  MIRROR=$OPTARG
            ;;
        r)  ROOTSIZE=$OPTARG
            ;;
        s)  SWAPSIZE=$OPTARG
            ;;
    esac
done
shift `expr $OPTIND - 1`

RELEASE=$1
FORMAT=$2

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
    *)          echo "Unknown format: $FORMAT"
                usage
esac

case $RELEASE in
    natty)      ;;
    maverick)   ;;
    lucid)      ;;
    karmic)     ;;
    jaunty)     ;;
    *)          echo "Unknown release: $RELEASE"
                usage
                ;;
esac

# Install stuff if necessary
if [ -z `which vmbuilder` ]; then
    sudo apt-get install ubuntu-vm-builder
fi

# Build the image
TMPDISK=`mktemp imgXXXXXXXX`
SIZE=$[$ROOTSIZE+$SWAPSIZE+1]
dd if=/dev/null of=$TMPDISK bs=1M seek=$SIZE
sudo vmbuilder $HYPER ubuntu --suite $RELEASE \
  -o \
  --rootsize=$ROOTSIZE \
  --swapsize=$SWAPSIZE \
  --tmpfs - \
  --addpkg=openssh-server \
  --raw=$TMPDISK \

if [ "$FORMAT" = "raw" ]; then
    # Get image
    mv $TMPDISK $RELEASE.$FORMAT
else
    # Convert image
    qemu-img convert -O $QFORMAT $TMPDISK $RELEASE.$FORMAT
    rm $TMPDISK
fi
rm -rf ubuntu-$HYPER
