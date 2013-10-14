#!/bin/bash

# This script must be run on a XenServer or XCP machine
#
# It creates a DomU VM that runs OpenStack services
#
# For more details see: README.md

set -o errexit
set -o nounset
set -o xtrace

export LC_ALL=C

# Abort if localrc is not set
if [ ! -e ../../localrc ]; then
    echo "You must have a localrc with ALL necessary passwords defined before proceeding."
    echo "See the xen README for required passwords."
    exit 1
fi

# This directory
THIS_DIR=$(cd $(dirname "$0") && pwd)

# Source lower level functions
. $THIS_DIR/../../functions

# Include onexit commands
. $THIS_DIR/scripts/on_exit.sh

# xapi functions
. $THIS_DIR/functions

# Determine what system we are running on.
# Might not be XenServer if we're using xenserver-core
GetDistro

#
# Get Settings
#

# Source params - override xenrc params in your localrc to suit your taste
source $THIS_DIR/xenrc

xe_min()
{
  local cmd="$1"
  shift
  xe "$cmd" --minimal "$@"
}

#
# Prepare Dom0
# including installing XenAPI plugins
#

cd $THIS_DIR

# Die if multiple hosts listed
if have_multiple_hosts; then
    cat >&2 << EOF
ERROR: multiple hosts found. This might mean that the XenServer is a member
of a pool - Exiting.
EOF
    exit 1
fi

# Install plugins

## Nova plugins
NOVA_ZIPBALL_URL=${NOVA_ZIPBALL_URL:-$(zip_snapshot_location $NOVA_REPO $NOVA_BRANCH)}
EXTRACTED_NOVA=$(extract_remote_zipball "$NOVA_ZIPBALL_URL")
install_xapi_plugins_from "$EXTRACTED_NOVA"

LOGROT_SCRIPT=$(find "$EXTRACTED_NOVA" -name "rotate_xen_guest_logs.sh" -print)
if [ -n "$LOGROT_SCRIPT" ]; then
    mkdir -p "/var/log/xen/guest"
    cp "$LOGROT_SCRIPT" /root/consolelogrotate
    chmod +x /root/consolelogrotate
    echo "* * * * * /root/consolelogrotate" | crontab
fi

rm -rf "$EXTRACTED_NOVA"

## Install the netwrap xapi plugin to support agent control of dom0 networking
if [[ "$ENABLED_SERVICES" =~ "q-agt" && "$Q_PLUGIN" = "openvswitch" ]]; then
    NEUTRON_ZIPBALL_URL=${NEUTRON_ZIPBALL_URL:-$(zip_snapshot_location $NEUTRON_REPO $NEUTRON_BRANCH)}
    EXTRACTED_NEUTRON=$(extract_remote_zipball "$NEUTRON_ZIPBALL_URL")
    install_xapi_plugins_from "$EXTRACTED_NEUTRON"
    rm -rf "$EXTRACTED_NEUTRON"
fi

create_directory_for_kernels
create_directory_for_images

#
# Configure Networking
#

MGT_NETWORK=`xe pif-list management=true params=network-uuid minimal=true`
MGT_BRIDGE_OR_NET_NAME=`xe network-list uuid=$MGT_NETWORK params=bridge minimal=true`

setup_network "$VM_BRIDGE_OR_NET_NAME"
setup_network "$MGT_BRIDGE_OR_NET_NAME"
setup_network "$PUB_BRIDGE_OR_NET_NAME"

# With neutron, one more network is required, which is internal to the
# hypervisor, and used by the VMs
if is_service_enabled neutron; then
    setup_network "$XEN_INT_BRIDGE_OR_NET_NAME"
fi

if parameter_is_specified "FLAT_NETWORK_BRIDGE"; then
    cat >&2 << EOF
ERROR: FLAT_NETWORK_BRIDGE is specified in localrc file
This is considered as an error, as its value will be derived from the
VM_BRIDGE_OR_NET_NAME variable's value.
EOF
    exit 1
fi

if ! xenapi_is_listening_on "$MGT_BRIDGE_OR_NET_NAME"; then
    cat >&2 << EOF
ERROR: XenAPI does not have an assigned IP address on the management network.
please review your XenServer network configuration / localrc file.
EOF
    exit 1
fi

HOST_IP=$(xenapi_ip_on "$MGT_BRIDGE_OR_NET_NAME")

# Set up ip forwarding, but skip on xcp-xapi
if [ -a /etc/sysconfig/network ]; then
    if ! grep -q "FORWARD_IPV4=YES" /etc/sysconfig/network; then
      # FIXME: This doesn't work on reboot!
      echo "FORWARD_IPV4=YES" >> /etc/sysconfig/network
    fi
fi
# Also, enable ip forwarding in rc.local, since the above trick isn't working
if ! grep -q  "echo 1 >/proc/sys/net/ipv4/ip_forward" /etc/rc.local; then
    echo "echo 1 >/proc/sys/net/ipv4/ip_forward" >> /etc/rc.local
fi
# Enable ip forwarding at runtime as well
echo 1 > /proc/sys/net/ipv4/ip_forward


#
# Shutdown previous runs
#

DO_SHUTDOWN=${DO_SHUTDOWN:-1}
CLEAN_TEMPLATES=${CLEAN_TEMPLATES:-false}
if [ "$DO_SHUTDOWN" = "1" ]; then
    # Shutdown all domU's that created previously
    clean_templates_arg=""
    if $CLEAN_TEMPLATES; then
        clean_templates_arg="--remove-templates"
    fi
    ./scripts/uninstall-os-vpx.sh $clean_templates_arg

    # Destroy any instances that were launched
    for uuid in `xe vm-list | grep -1 instance | grep uuid | sed "s/.*\: //g"`; do
        echo "Shutting down nova instance $uuid"
        xe vm-uninstall uuid=$uuid force=true
    done

    # Destroy orphaned vdis
    for uuid in `xe vdi-list | grep -1 Glance | grep uuid | sed "s/.*\: //g"`; do
        xe vdi-destroy uuid=$uuid
    done
fi


#
# Create Ubuntu VM template
# and/or create VM from template
#

GUEST_NAME=${GUEST_NAME:-"DevStackOSDomU"}
TNAME="jeos_template_for_devstack"
SNAME_TEMPLATE="jeos_snapshot_for_devstack"
SNAME_FIRST_BOOT="before_first_boot"

function wait_for_VM_to_halt() {
    set +x
    echo "Waiting for the VM to halt.  Progress in-VM can be checked with vncviewer:"
    mgmt_ip=$(echo $XENAPI_CONNECTION_URL | tr -d -c '1234567890.')
    domid=$(xe vm-list name-label="$GUEST_NAME" params=dom-id minimal=true)
    port=$(xenstore-read /local/domain/$domid/console/vnc-port)
    echo "vncviewer -via root@$mgmt_ip localhost:${port:2}"
    while true
    do
        state=$(xe_min vm-list name-label="$GUEST_NAME" power-state=halted)
        if [ -n "$state" ]
        then
            break
        else
            echo -n "."
            sleep 20
        fi
    done
    set -x
}

templateuuid=$(xe template-list name-label="$TNAME")
if [ -z "$templateuuid" ]; then
    #
    # Install Ubuntu over network
    #
    UBUNTU_INST_BRIDGE_OR_NET_NAME=${UBUNTU_INST_BRIDGE_OR_NET_NAME:-"$MGT_BRIDGE_OR_NET_NAME"}

    # always update the preseed file, incase we have a newer one
    PRESEED_URL=${PRESEED_URL:-""}
    if [ -z "$PRESEED_URL" ]; then
        PRESEED_URL="${HOST_IP}/devstackubuntupreseed.cfg"
        HTTP_SERVER_LOCATION="/opt/xensource/www"
        if [ ! -e $HTTP_SERVER_LOCATION ]; then
            HTTP_SERVER_LOCATION="/var/www/html"
            mkdir -p $HTTP_SERVER_LOCATION
        fi
        cp -f $THIS_DIR/devstackubuntupreseed.cfg $HTTP_SERVER_LOCATION

        sed \
            -e "s,\(d-i mirror/http/hostname string\).*,\1 $UBUNTU_INST_HTTP_HOSTNAME,g" \
            -e "s,\(d-i mirror/http/directory string\).*,\1 $UBUNTU_INST_HTTP_DIRECTORY,g" \
            -e "s,\(d-i mirror/http/proxy string\).*,\1 $UBUNTU_INST_HTTP_PROXY,g" \
            -i "${HTTP_SERVER_LOCATION}/devstackubuntupreseed.cfg"
    fi

    # Update the template
    $THIS_DIR/scripts/install_ubuntu_template.sh $PRESEED_URL

    # create a new VM from the given template with eth0 attached to the given
    # network
    $THIS_DIR/scripts/install-os-vpx.sh \
        -t "$UBUNTU_INST_TEMPLATE_NAME" \
        -n "$UBUNTU_INST_BRIDGE_OR_NET_NAME" \
        -l "$GUEST_NAME"

    set_vm_memory "$GUEST_NAME" "$OSDOMU_MEM_MB"

    xe vm-start vm="$GUEST_NAME"

    # wait for install to finish
    wait_for_VM_to_halt

    # set VM to restart after a reboot
    vm_uuid=$(xe_min vm-list name-label="$GUEST_NAME")
    xe vm-param-set actions-after-reboot=Restart uuid="$vm_uuid"

    # Make template from VM
    snuuid=$(xe vm-snapshot vm="$GUEST_NAME" new-name-label="$SNAME_TEMPLATE")
    xe snapshot-clone uuid=$snuuid new-name-label="$TNAME"
else
    #
    # Template already installed, create VM from template
    #
    vm_uuid=$(xe vm-install template="$TNAME" new-name-label="$GUEST_NAME")
fi

#
# Prepare VM for DevStack
#

# Install XenServer tools, and other such things
$THIS_DIR/prepare_guest_template.sh "$GUEST_NAME"

# Set virtual machine parameters
set_vm_memory "$GUEST_NAME" "$OSDOMU_MEM_MB"

# Max out VCPU count for better performance
max_vcpus "$GUEST_NAME"

# start the VM to run the prepare steps
xe vm-start vm="$GUEST_NAME"

# Wait for prep script to finish and shutdown system
wait_for_VM_to_halt

## Setup network cards
# Wipe out all
destroy_all_vifs_of "$GUEST_NAME"
# Tenant network
add_interface "$GUEST_NAME" "$VM_BRIDGE_OR_NET_NAME" "$VM_DEV_NR"
# Management network
add_interface "$GUEST_NAME" "$MGT_BRIDGE_OR_NET_NAME" "$MGT_DEV_NR"
# Public network
add_interface "$GUEST_NAME" "$PUB_BRIDGE_OR_NET_NAME" "$PUB_DEV_NR"

#
# Inject DevStack inside VM disk
#
$THIS_DIR/build_xva.sh "$GUEST_NAME"

# Attach a network interface for the integration network (so that the bridge
# is created by XenServer). This is required for Neutron. Also pass that as a
# kernel parameter for DomU
if is_service_enabled neutron; then
    attach_network "$XEN_INT_BRIDGE_OR_NET_NAME"

    XEN_INTEGRATION_BRIDGE=$(bridge_for "$XEN_INT_BRIDGE_OR_NET_NAME")
    append_kernel_cmdline \
        "$GUEST_NAME" \
        "xen_integration_bridge=${XEN_INTEGRATION_BRIDGE}"
fi

FLAT_NETWORK_BRIDGE=$(bridge_for "$VM_BRIDGE_OR_NET_NAME")
append_kernel_cmdline "$GUEST_NAME" "flat_network_bridge=${FLAT_NETWORK_BRIDGE}"

# Add a separate xvdb, if it was requested
if [[ "0" != "$XEN_XVDB_SIZE_GB" ]]; then
    vm=$(xe vm-list name-label="$GUEST_NAME" --minimal)

    # Add a new disk
    localsr=$(get_local_sr)
    extra_vdi=$(xe vdi-create \
        name-label=xvdb-added-by-devstack \
        virtual-size="${XEN_XVDB_SIZE_GB}GiB" \
        sr-uuid=$localsr type=user)
    xe vbd-create vm-uuid=$vm vdi-uuid=$extra_vdi device=1
fi

# create a snapshot before the first boot
# to allow a quick re-run with the same settings
xe vm-snapshot vm="$GUEST_NAME" new-name-label="$SNAME_FIRST_BOOT"

#
# Run DevStack VM
#
xe vm-start vm="$GUEST_NAME"

function ssh_no_check() {
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$@"
}

# Get hold of the Management IP of OpenStack VM
OS_VM_MANAGEMENT_ADDRESS=$MGT_IP
if [ $OS_VM_MANAGEMENT_ADDRESS == "dhcp" ]; then
    OS_VM_MANAGEMENT_ADDRESS=$(find_ip_by_name $GUEST_NAME $MGT_DEV_NR)
fi

# Get hold of the Service IP of OpenStack VM
if [ $HOST_IP_IFACE == "eth${MGT_DEV_NR}" ]; then
    OS_VM_SERVICES_ADDRESS=$MGT_IP
    if [ $MGT_IP == "dhcp" ]; then
        OS_VM_SERVICES_ADDRESS=$(find_ip_by_name $GUEST_NAME $MGT_DEV_NR)
    fi
else
    OS_VM_SERVICES_ADDRESS=$PUB_IP
    if [ $PUB_IP == "dhcp" ]; then
        OS_VM_SERVICES_ADDRESS=$(find_ip_by_name $GUEST_NAME $PUB_DEV_NR)
    fi
fi

# If we have copied our ssh credentials, use ssh to monitor while the installation runs
WAIT_TILL_LAUNCH=${WAIT_TILL_LAUNCH:-1}
COPYENV=${COPYENV:-1}
if [ "$WAIT_TILL_LAUNCH" = "1" ]  && [ -e ~/.ssh/id_rsa.pub  ] && [ "$COPYENV" = "1" ]; then
    set +x

    echo "VM Launched - Waiting for startup script"
    # wait for log to appear
    while ! ssh_no_check -q stack@$OS_VM_MANAGEMENT_ADDRESS "[ -e run.sh.log ]"; do
        sleep 10
    done
    echo -n "Running"
    while [ `ssh_no_check -q stack@$OS_VM_MANAGEMENT_ADDRESS pgrep -c run.sh` -ge 1 ]
    do
        sleep 10
        echo -n "."
    done
    echo "done!"
    set -x

    # output the run.sh.log
    ssh_no_check -q stack@$OS_VM_MANAGEMENT_ADDRESS 'cat run.sh.log'

    # Fail if the expected text is not found
    ssh_no_check -q stack@$OS_VM_MANAGEMENT_ADDRESS 'cat run.sh.log' | grep -q 'stack.sh completed in'

    set +x
    echo "################################################################################"
    echo ""
    echo "All Finished!"
    echo "You can visit the OpenStack Dashboard"
    echo "at http://$OS_VM_SERVICES_ADDRESS, and contact other services at the usual ports."
else
    set +x
    echo "################################################################################"
    echo ""
    echo "All Finished!"
    echo "Now, you can monitor the progress of the stack.sh installation by "
    echo "tailing /opt/stack/run.sh.log from within your domU."
    echo ""
    echo "ssh into your domU now: 'ssh stack@$OS_VM_MANAGEMENT_ADDRESS' using your password"
    echo "and then do: 'tail -f /opt/stack/run.sh.log'"
    echo ""
    echo "When the script completes, you can then visit the OpenStack Dashboard"
    echo "at http://$OS_VM_SERVICES_ADDRESS, and contact other services at the usual ports."
fi
