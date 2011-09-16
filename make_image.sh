#!/bin/bash
# make_image.sh - Create Ubuntu images in various formats
#
# make_image.sh release format
#
# Supported formats: qcow (kvm), vmdk (vmserver), vdi (vbox), vhd (vpc)
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
        h)	usage
		;;
	m)	MIRROR=$OPTARG
		;;
	r)	ROOTSIZE=$OPTARG
		;;
	s)	SWAPSIZE=$OPTARG
		;;
    esac
done
shift `expr $OPTIND - 1`

RELEASE=$1
FORMAT=$2

case $RELEASE in
    natty)	;;
    maverick)	;;
    lucid)	;;
    karmic)	;;
    jaunty)	;;
    *)		echo "Unknown release: $RELEASE"
		usage
esac

case $FORMAT in
    kvm|qcow2)	FORMAT=qcow2
		TARGET=kvm
		;;
    vmserver|vmdk)	FORMAT=vmdk
		TARGET=vmserver
		;;
    vbox|vdi)	FORMAT=qcow2
		TARGET=kvm
		FINAL_FORMAT=vdi
		;;
    vhd|vpc)	FORMAT=qcow2
		TARGET=kvm
		FINAL_FORMAT=vpc
		;;
    *)		echo "Unknown format: $FORMAT"
		usage
esac

# Install stuff if necessary
if [ -z `which vmbuilder` ]; then
	sudo apt-get install ubuntu-vm-builder
fi

# Build the image
sudo vmbuilder $TARGET ubuntu --suite $RELEASE \
  -o \
  --rootsize=$ROOTSIZE \
  --swapsize=$SWAPSIZE \
  --tmpfs - \
  --addpkg=openssh-server \

#  --mirror=$MIRROR \

if [ -z "$FINAL_FORMAT" ]; then
    # Get image
    mv ubuntu-$TARGET/tmp*.$FORMAT $RELEASE.$FORMAT
else
    # Convert image
    qemu-img convert -O $FINAL_FORMAT ubuntu-$TARGET/tmp*.$FORMAT $RELEASE.$FINAL_FORMAT
fi
rm -rf ubuntu-$TARGET
