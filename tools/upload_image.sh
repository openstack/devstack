#!/bin/bash
# upload_image.sh - Upload Ubuntu images (create if necessary) in various formats
# Supported formats: qcow (kvm), vmdk (vmserver), vdi (vbox), vhd (vpc)
# Requires sudo to root

usage() {
    echo "$0 - Upload images to OpenStack"
    echo ""
    echo "$0 [-h host] [-p port] release format"
    exit 1
}

HOST=${HOST:-localhost}
PORT=${PORT:-9292}
DEST=${DEST:-/opt/stack}

while getopts h:p: c; do
    case $c in
        h)  HOST=$OPTARG
            ;;
        p)  PORT=$OPTARG
            ;;
    esac
done
shift `expr $OPTIND - 1`

RELEASE=$1
FORMAT=$2

case $FORMAT in
    kvm|qcow2)  FORMAT=qcow2
                TARGET=kvm
                ;;
    vmserver|vmdk)
                FORMAT=vmdk
                TARGET=vmserver
                ;;
    vbox|vdi)   TARGET=kvm
                FORMAT=vdi
                ;;
    vhd|vpc)    TARGET=kvm
                FORMAT=vhd
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
    *)          if [ ! -r $RELEASE.$FORMAT ]; then
                    echo "Unknown release: $RELEASE"
                    usage
                fi
                ;;
esac

GLANCE=`which glance`
if [ -z "$GLANCE" ]; then
    if [ -x "$DEST/glance/bin/glance" ]; then
        # Look for stack.sh's install
        GLANCE="$DEST/glance/bin/glance"
    else
        # Install Glance client in $DEST
        echo "Glance not found, must install client"
        OWD=`pwd`
        cd $DEST
        sudo apt-get install python-pip python-eventlet python-routes python-greenlet python-argparse python-sqlalchemy python-wsgiref python-pastedeploy python-xattr
        sudo pip install kombu
        sudo git clone https://github.com/cloudbuilders/glance.git
        cd glance
        sudo python setup.py develop
        cd $OWD
        GLANCE=`which glance`
    fi
fi

# Create image if it doesn't exist
if [ ! -r $RELEASE.$FORMAT ]; then
    DIR=`dirname $0`
    echo "$RELEASE.$FORMAT not found, creating..."
    $DIR/make_image.sh $RELEASE $FORMAT
fi

# Upload the image
echo "Uploading image $RELEASE.$FORMAT to $HOST"
$GLANCE add name=$RELEASE.$FORMAT is_public=true disk_format=$FORMAT --host $HOST --port $PORT <$RELEASE.$FORMAT
