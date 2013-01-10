#!/bin/bash

# **make_cert.sh**

# Create a CA hierarchy (if necessary) and server certificate
#
# This mimics the CA structure that DevStack sets up when ``tls_proxy`` is enabled
# but in the curent directory unless ``DATA_DIR`` is set

ENABLE_TLS=True
DATA_DIR=${DATA_DIR:-`pwd`/ca-data}

ROOT_CA_DIR=$DATA_DIR/root
INT_CA_DIR=$DATA_DIR/int

# Import common functions
source $TOP_DIR/functions

# Import TLS functions
source lib/tls

function usage {
    echo "$0 - Create CA and/or certs"
    echo ""
    echo "Usage: $0 commonName [orgUnit]"
    exit 1
}

CN=$1
if [ -z "$CN" ]]; then
    usage
fi
ORG_UNIT_NAME=${2:-$ORG_UNIT_NAME}

# Useful on OS/X
if [[ `uname -s` == 'Darwin' && -d /usr/local/Cellar/openssl ]]; then
    # set up for brew-installed modern OpenSSL
    OPENSSL_CONF=/usr/local/etc/openssl/openssl.cnf
    OPENSSL=/usr/local/Cellar/openssl/*/bin/openssl
fi

DEVSTACK_CERT_NAME=$CN
DEVSTACK_HOSTNAME=$CN
DEVSTACK_CERT=$DATA_DIR/$DEVSTACK_CERT_NAME.pem

# Make sure the CA is set up
configure_CA
init_CA

# Create the server cert
make_cert $INT_CA_DIR $DEVSTACK_CERT_NAME $DEVSTACK_HOSTNAME

# Create a cert bundle
cat $INT_CA_DIR/private/$DEVSTACK_CERT_NAME.key $INT_CA_DIR/$DEVSTACK_CERT_NAME.crt $INT_CA_DIR/cacert.pem >$DEVSTACK_CERT

