#!/bin/bash

# **install_openvpn.sh**

# Install OpenVPN and generate required certificates
#
# install_openvpn.sh --client name
# install_openvpn.sh --server [name]
#
# name is used on the CN of the generated cert, and the filename of
# the configuration, certificate and key files.
#
# --server mode configures the host with a running OpenVPN server instance
# --client mode creates a tarball of a client configuration for this server

# Get config file
if [ -e localrc ]; then
    . localrc
fi
if [ -e vpnrc ]; then
    . vpnrc
fi

# Do some IP manipulation
function cidr2netmask {
    set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
    if [[ $1 -gt 1 ]]; then
        shift $1
    else
        shift
    fi
    echo ${1-0}.${2-0}.${3-0}.${4-0}
}

FIXED_NET=`echo $FIXED_RANGE | cut -d'/' -f1`
FIXED_CIDR=`echo $FIXED_RANGE | cut -d'/' -f2`
FIXED_MASK=`cidr2netmask $FIXED_CIDR`

# VPN Config
VPN_SERVER=${VPN_SERVER:-`ifconfig eth0 | awk "/inet addr:/ { print \$2 }" | cut -d: -f2`}  # 50.56.12.212
VPN_PROTO=${VPN_PROTO:-tcp}
VPN_PORT=${VPN_PORT:-6081}
VPN_DEV=${VPN_DEV:-tap0}
VPN_BRIDGE=${VPN_BRIDGE:-br100}
VPN_BRIDGE_IF=${VPN_BRIDGE_IF:-$FLAT_INTERFACE}
VPN_CLIENT_NET=${VPN_CLIENT_NET:-$FIXED_NET}
VPN_CLIENT_MASK=${VPN_CLIENT_MASK:-$FIXED_MASK}
VPN_CLIENT_DHCP="${VPN_CLIENT_DHCP:-net.1 net.254}"

VPN_DIR=/etc/openvpn
CA_DIR=$VPN_DIR/easy-rsa

function usage {
    echo "$0 - OpenVPN install and certificate generation"
    echo ""
    echo "$0 --client name"
    echo "$0 --server [name]"
    echo ""
    echo " --server mode configures the host with a running OpenVPN server instance"
    echo " --client mode creates a tarball of a client configuration for this server"
    exit 1
}

if [ -z $1 ]; then
    usage
fi

# Install OpenVPN
VPN_EXEC=`which openvpn`
if [ -z "$VPN_EXEC" -o ! -x "$VPN_EXEC" ]; then
    apt-get install -y openvpn bridge-utils
fi
if [ ! -d $CA_DIR ]; then
    cp -pR /usr/share/doc/openvpn/examples/easy-rsa/2.0/ $CA_DIR
fi

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $TOOLS_DIR/.. && pwd)

WEB_DIR=$TOP_DIR/../vpn
if [[ ! -d $WEB_DIR ]]; then
    mkdir -p $WEB_DIR
fi
WEB_DIR=$(cd $TOP_DIR/../vpn && pwd)

cd $CA_DIR
source ./vars

# Override the defaults
export KEY_COUNTRY="US"
export KEY_PROVINCE="TX"
export KEY_CITY="SanAntonio"
export KEY_ORG="Cloudbuilders"
export KEY_EMAIL="rcb@lists.rackspace.com"

if [ ! -r $CA_DIR/keys/dh1024.pem ]; then
    # Initialize a new CA
    $CA_DIR/clean-all
    $CA_DIR/build-dh
    $CA_DIR/pkitool --initca
    openvpn --genkey --secret $CA_DIR/keys/ta.key  ## Build a TLS key
fi

function do_server {
    NAME=$1
    # Generate server certificate
    $CA_DIR/pkitool --server $NAME

    (cd $CA_DIR/keys;
        cp $NAME.crt $NAME.key ca.crt dh1024.pem ta.key $VPN_DIR
    )
    cat >$VPN_DIR/br-up <<EOF
#!/bin/bash

BR="$VPN_BRIDGE"
TAP="\$1"

if [[ ! -d /sys/class/net/\$BR ]]; then
    brctl addbr \$BR
fi

for t in \$TAP; do
    openvpn --mktun --dev \$t
    brctl addif \$BR \$t
    ifconfig \$t 0.0.0.0 promisc up
done
EOF
    chmod +x $VPN_DIR/br-up
    cat >$VPN_DIR/br-down <<EOF
#!/bin/bash

BR="$VPN_BRIDGE"
TAP="\$1"

for i in \$TAP; do
    brctl delif \$BR $t
    openvpn --rmtun --dev \$i
done
EOF
    chmod +x $VPN_DIR/br-down
    cat >$VPN_DIR/$NAME.conf <<EOF
proto $VPN_PROTO
port $VPN_PORT
dev $VPN_DEV
up $VPN_DIR/br-up
down $VPN_DIR/br-down
cert $NAME.crt
key $NAME.key  # This file should be kept secret
ca ca.crt
dh dh1024.pem
duplicate-cn
server-bridge $VPN_CLIENT_NET $VPN_CLIENT_MASK $VPN_CLIENT_DHCP
ifconfig-pool-persist ipp.txt
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
EOF
    /etc/init.d/openvpn restart
}

function do_client {
    NAME=$1
    # Generate a client certificate
    $CA_DIR/pkitool $NAME

    TMP_DIR=`mktemp -d`
    (cd $CA_DIR/keys;
        cp -p ca.crt ta.key $NAME.key $NAME.crt $TMP_DIR
    )
    if [ -r $VPN_DIR/hostname ]; then
        HOST=`cat $VPN_DIR/hostname`
    else
        HOST=`hostname`
    fi
    cat >$TMP_DIR/$HOST.conf <<EOF
proto $VPN_PROTO
port $VPN_PORT
dev $VPN_DEV
cert $NAME.crt
key $NAME.key  # This file should be kept secret
ca ca.crt
client
remote $VPN_SERVER $VPN_PORT
resolv-retry infinite
nobind
user nobody
group nogroup
persist-key
persist-tun
comp-lzo
verb 3
EOF
    (cd $TMP_DIR; tar cf $WEB_DIR/$NAME.tar *)
    rm -rf $TMP_DIR
    echo "Client certificate and configuration is in $WEB_DIR/$NAME.tar"
}

# Process command line args
case $1 in
    --client)   if [ -z $2 ]; then
                    usage
                fi
                do_client $2
                ;;
    --server)   if [ -z $2 ]; then
                    NAME=`hostname`
                else
                    NAME=$2
                    # Save for --client use
                    echo $NAME >$VPN_DIR/hostname
                fi
                do_server $NAME
                ;;
    --clean)    $CA_DIR/clean-all
                ;;
    *)          usage
esac
