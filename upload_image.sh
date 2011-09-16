#!/bin/bash
# upload_image.sh - Upload Ubuntu images (create if necessary) in various formats
#
# upload_image.sh release format
#
# format   target
# qcow2    kvm,qemu
# vmdk     vmw6
# vbox     vdi
# vhd      vpc

HOST=${HOST:-demo.rcb.me}
PORT=${PORT:-9292}

usage() {
    echo "$0 - Upload Ubuntu images"
    echo ""
    echo "$0 [-h host] [-p port] release format"
    exit 1
}

while getopts h:p: c; do
    case $c in
        h)      HOST=$OPTARG
                ;;
	p)	PORT=$OPTARG
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
    vbox|vdi)	TARGET=kvm
		FORMAT=vdi
		;;
    vhd|vpc)	TARGET=kvm
		FORMAT=vpc
		;;
    *)		echo "Unknown format: $FORMAT"
		usage
esac

GLANCE=`which glance`
if [ -z "$GLANCE" ]; then
	echo "Glance not found, must install client"
	sudo apt-get install python-pip python-eventlet python-routes python-greenlet python-argparse python-sqlalchemy python-wsgiref python-pastedeploy python-xattr
	sudo pip install kombu
	git clone https://github.com/cloudbuilders/glance.git
	cd glance
	sudo python setup.py develop
	cd ..
	GLANCE=`which glance`
fi

# Create image if it doesn't exist
if [ ! -r $RELEASE.$FORMAT ]; then
	DIR=`dirname $0`
	echo "$RELEASE.$FORMAT not found, creating...must be root to do this:"
	$DIR/make_image.sh $RELEASE $FORMAT
fi

# Upload the image
$GLANCE add name=$RELEASE.$FORMAT is_public=true disk_format=$FORMAT --host $HOST --port $PORT <$RELEASE.$FORMAT
