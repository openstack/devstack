#!/bin/bash
#
# This creates an Ubuntu Server 32bit or 64bit template
# on Xenserver 5.6.x, 6.0.x and 6.1.x
# The template does a net install only
#
# Based on a script by: David Markey <david.markey@citrix.com>
#

set -o errexit
set -o nounset
set -o xtrace

# This directory
BASE_DIR=$(cd $(dirname "$0") && pwd)

# For default setings see xenrc
source $BASE_DIR/../xenrc

# Get the params
preseed_url=$1

# Delete template or skip template creation as required
previous_template=$(xe template-list name-label="$UBUNTU_INST_TEMPLATE_NAME" \
    params=uuid --minimal)
if [ -n "$previous_template" ]; then
    if $CLEAN_TEMPLATES; then
        xe template-param-clear param-name=other-config uuid=$previous_template
        xe template-uninstall template-uuid=$previous_template force=true
    else
        echo "Template $UBUNTU_INST_TEMPLATE_NAME already present"
        exit 0
    fi
fi

# Get built-in template
builtin_name="Debian Squeeze 6.0 (32-bit)"
builtin_uuid=$(xe template-list name-label="$builtin_name" --minimal)
if [[ -z $builtin_uuid ]]; then
    echo "Can't find the Debian Squeeze 32bit template on your XenServer."
    exit 1
fi

# Clone built-in template to create new template
new_uuid=$(xe vm-clone uuid=$builtin_uuid \
    new-name-label="$UBUNTU_INST_TEMPLATE_NAME")
disk_size=$(($OSDOMU_VDI_GB * 1024 * 1024 * 1024))

# Some of these settings can be found in example preseed files
# however these need to be answered before the netinstall
# is ready to fetch the preseed file, and as such must be here
# to get a fully automated install
pvargs="-- quiet console=hvc0 partman/default_filesystem=ext3 \
console-setup/ask_detect=false locale=${UBUNTU_INST_LOCALE} \
keyboard-configuration/layoutcode=${UBUNTU_INST_KEYBOARD} \
netcfg/choose_interface=${UBUNTU_INST_IFACE} \
netcfg/get_hostname=os netcfg/get_domain=os auto \
url=${preseed_url}"

if [ "$UBUNTU_INST_IP" != "dhcp" ]; then
    netcfgargs="netcfg/disable_autoconfig=true \
netcfg/get_nameservers=${UBUNTU_INST_NAMESERVERS} \
netcfg/get_ipaddress=${UBUNTU_INST_IP} \
netcfg/get_netmask=${UBUNTU_INST_NETMASK} \
netcfg/get_gateway=${UBUNTU_INST_GATEWAY} \
netcfg/confirm_static=true"
    pvargs="${pvargs} ${netcfgargs}"
fi

xe template-param-set uuid=$new_uuid \
    other-config:install-methods=http \
    other-config:install-repository="http://${UBUNTU_INST_HTTP_HOSTNAME}${UBUNTU_INST_HTTP_DIRECTORY}" \
    PV-args="$pvargs" \
    other-config:debian-release="$UBUNTU_INST_RELEASE" \
    other-config:default_template=true \
    other-config:disks='<provision><disk device="0" size="'$disk_size'" sr="" bootable="true" type="system"/></provision>' \
    other-config:install-arch="$UBUNTU_INST_ARCH"

if ! [ -z "$UBUNTU_INST_HTTP_PROXY" ]; then
    xe template-param-set uuid=$new_uuid \
        other-config:install-proxy="$UBUNTU_INST_HTTP_PROXY"
fi

echo "Ubuntu template installed uuid:$new_uuid"
