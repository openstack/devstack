#!/bin/bash
## makeubuntu.sh, this creates Ubuntu server 11.10 32 and 64 bit templates
## on Xenserver 6.0.2 Net install only
## Original Author: David Markey <david.markey@citrix.com>
## Author: Renuka Apte <renuka.apte@citrix.com>
## This is not an officially supported guest OS on XenServer 6.0.2

BASE_DIR=$(cd $(dirname "$0") && pwd)
source $BASE_DIR/../../../localrc

LENNY=$(xe template-list name-label=Debian\ Lenny\ 5.0\ \(32-bit\) --minimal)

if [[ -z $LENNY ]] ; then
    echo "Cant find lenny 32bit template, is this on 6.0.2?"
    exit 1
fi

distro="Ubuntu 11.10 for DevStack"
arches=("32-bit" "64-bit")

preseedurl=${1:-"http://images.ansolabs.com/devstackubuntupreseed.cfg"}

NETINSTALL_LOCALE=${NETINSTALL_LOCALE:-en_US}
NETINSTALL_KEYBOARD=${NETINSTALL_KEYBOARD:-us}
NETINSTALL_IFACE=${NETINSTALL_IFACE:-eth3}

for arch in ${arches[@]} ; do
    echo "Attempting $distro ($arch)"
    if [[ -n $(xe template-list name-label="$distro ($arch)" params=uuid --minimal) ]] ; then
        echo "$distro ($arch)" already exists, Skipping
    else
        if [ -z $NETINSTALLIP ]
        then
            echo "NETINSTALLIP not set in localrc"
            exit 1
        fi
        # Some of these settings can be found in example preseed files
        # however these need to be answered before the netinstall
        # is ready to fetch the preseed file, and as such must be here
        # to get a fully automated install
        pvargs="-- quiet console=hvc0 partman/default_filesystem=ext3 locale=${NETINSTALL_LOCALE} console-setup/ask_detect=false keyboard-configuration/layoutcode=${NETINSTALL_KEYBOARD} netcfg/choose_interface=${NETINSTALL_IFACE} netcfg/get_hostname=os netcfg/get_domain=os auto url=${preseedurl}"
        if [ "$NETINSTALLIP" != "dhcp" ]
        then
            netcfgargs="netcfg/disable_autoconfig=true netcfg/get_nameservers=${NAMESERVERS} netcfg/get_ipaddress=${NETINSTALLIP} netcfg/get_netmask=${NETMASK} netcfg/get_gateway=${GATEWAY} netcfg/confirm_static=true"
            pvargs="${pvargs} ${netcfgargs}"
        fi
        NEWUUID=$(xe vm-clone uuid=$LENNY new-name-label="$distro ($arch)")
        xe template-param-set uuid=$NEWUUID other-config:install-methods=http,ftp \
         other-config:install-repository=http://archive.ubuntu.net/ubuntu \
         PV-args="$pvargs" \
         other-config:debian-release=oneiric \
         other-config:default_template=true

        if [[ "$arch" == "32-bit" ]] ; then
            xe template-param-set uuid=$NEWUUID other-config:install-arch="i386"
        else
            xe template-param-set uuid=$NEWUUID other-config:install-arch="amd64"
        fi
        echo "Success"
    fi
done

echo "Done"
