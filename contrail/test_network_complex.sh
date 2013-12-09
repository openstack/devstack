#! /bin/bash
#
# test_network_complex.sh
#
# test a complex network:
#
#
#    net1        net2        net3        net4
#     |           |           |           |
#     |           +- vrouter -+           |
#     |  1     2  |           |           |
#     +--- vm1 ---+           +- vrouter -+
#     |        f  |  1     2  |           |
#     |           +--- vm3 ---+           |
#     |  2     1  |           |    vm8 ---+
#     +--- vm2 ---+           |           |
#     |           |  2     1  |           |
#     |           +--- vm6 ---+           |
#     |           |           |           |
#     +-----------------+     |           |
#     |           |     |     |           |
#     |           |    1|     |           |
#     |           +--- vm7 ---+           |
#     |           |  2     3  |           |
#     +--- vm4    |           |           |
#     |           |    vm9 ---+           |
#     |           |           |           |
#     |    vm5----+           |           |
#     |           |           |           |
#
#
# vm1: net1, net2, float on net2
# vm2: net2, net1
# vm4: net1
# vm5: net2
# vm3: net2, net3
# vm6: net3, net2
# vm7: net1, net2, net3
# vm9: net3
# vm8: net4

# die on errors
set -ex

# source openrc after stack.sh completes to join the demo project as admin user
. ./openrc admin demo

# add this script's directory to the path
THIS_DIR=$(pwd)$(dirname ${BASH_SOURCE[0]})
PATH=$THIS_DIR:$PATH

# functions

die() {
    echo "ERROR: " "$@" >&2
    exit 1
}

# create a network with $net_name and return its id
net_create() {
    net_name="$1"
    neutron net-create -f shell -c id $net_name | sed -ne '/^id=/p' || \
	die "Couldn't create network $net_name"
}

# floatingip_create net_id
#
# create a floating ip on a network.  The network must have a
# floatingip pool created for it.  See create_floating_pool.py
#
floatingip_create() {
    local net_id=$1

    eval $(neutron floatingip-create -f shell -c id $net_id | sed -ne /id=/p || \
	die "couldn't create floating ip")
    floatingip_id=$id
    echo $floatingip_id=floatingip_id
}

# floatingip_associate vm_name net_name floatingip_id
# 
# assign floatingip_id to vm_name's interface on net_name
#
floatingip_associate() {
    local vm_name=$1
    local net_name=$2
    local floatingip_id=$3

    # find the port that the vm is attached to
    vm_net_ip=$(nova show $vm_name | sed -ne 's/^| '"$net_name"' network[ \t]*|[ \t]*\([.0-9]*\)[ \t]*|/\1/p' || \
	die "couldn't find $vm_name's ip on network $net_name")
    port_id=$(neutron port-list | sed -ne 's/| \([-0-9a-f]*\)[ \t]*|[ \t]*.*'"$vm_net_ip"'.*/\1/p' || \
	die "couldn't find prt_id for ip $vm_net_ip")
    neutron floatingip-associate $floatingip_id $port_id
}


# test script

# secgroup allow ping and ssh
nova secgroup-list
nova secgroup-list-rules default
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
nova secgroup-list-rules default

# net1
eval $(net_create net1)
net1_id=$id
neutron subnet-create --name net1-subnet1 $net1_id 10.1.0.0/24

# net2 (cloud)
eval $(net_create net2)
net2_id=$id
echo "net2_id=$net2_id"
neutron subnet-create --name net2-subnet1 $net2_id 10.2.0.0/24

# net3 (public)
eval $(net_create net3)
net3_id=$id
echo "net3_id=$net3_id"
# CONTRAIL_VGW_PUBLIC_SUBNET is set in localrc to be publicly addressable ips
neutron subnet-create --name net3-subnet1 $net3_id $CONTRAIL_VGW_PUBLIC_SUBNET --disable-dhcp

# call contrail to create floating ip pool
python /opt/stack/contrail/controller/src/config/utils/create_floating_pool.py --public_vn_name default-domain:$OS_TENANT_NAME:net3 --floating_ip_pool_name floatingip_pool
python /opt/stack/contrail/controller/src/config/utils/use_floating_pool.py --project_name default-domain:$OS_TENANT_NAME --floating_ip_pool_name default-domain:$OS_TENANT_NAME:net3:floatingip_pool

# net4 (new)
eval $(net_create net4)
net4_id=$id
echo "net4_id=$net4_id"
neutron subnet-create --name net4-subnet1 $net4_id 10.4.0.0/24


# call contrail to join networks, like a vrouter would
# if the net_policy_join script exists, then use it to join net1 and net2
# use ${BASH_SOURCE[0]} instead of $0, because it works when this script is sourced
net_policy_join.py $net2_id $net3_id
net_policy_join.py $net3_id $net4_id

# try to use a fixed cirros image that boots all network interfaces.
# default image name: cirros-test
IMAGE_NAME=${IMAGE_NAME:-cirros-test}
IMAGE_FILE=${IMAGE_FILE:-~/projects/piston/projects/cirros/cirros-0.3.1-x86_64-nbk.qcow2}
image=""
if glance image-show $IMAGE_NAME > /dev/null 2>&1; then
    image=$IMAGE_NAME
fi
if [ ! "$image" ] && [ -e $IMAGE_FILE ] && \
    glance image-create --name=$IMAGE_NAME --disk-format qcow2  --container-format=bare  < $IMAGE_FILE; then
    image=$IMAGE_NAME
fi
if [ ! "$image" ]; then 
    # fall back to stock cirros
    image=cirros-0.3.1-x86_64-uec
fi

# make an ssh key
yes | ssh-keygen -N "" -f sshkey
nova keypair-add --pub-key sshkey.pub sshkey

# cloudinit script to verify that the metadata server is working
tee cloudinit.sh <<EOF
#! /bin/sh
echo "Cloudinit worked!"
echo

echo "Inet interfaces:"
ip -f inet -o addr list
EOF
chmod a+x cloudinit.sh

# vm parameters
flavor=m1.tiny
vm_params="--image $image --flavor $flavor --key-name sshkey --user-data cloudinit.sh"


# vms

# vm1: net1, net2, float on net2
nova boot $vm_params --nic net-id=$net1_id --nic net-id=$net2_id vm1
# floatingip1 for vm1,net2
eval $(floatingip_create $net3_id)
floatingip1_id=$floatingip_id
floatingip_associate vm1 net2 $floatingip1_id
neutron floatingip-show $floatingip1_id

# vm2: net2, net1
nova boot $vm_params --nic net-id=$net2_id --nic net-id=$net1_id vm2

# vm4: net1
nova boot $vm_params --nic net-id=$net1_id vm4

# vm5: net2
nova boot $vm_params --nic net-id=$net2_id vm5

# vm3: net2, net3
nova boot $vm_params --nic net-id=$net2_id --nic net-id=$net3_id vm3

# vm6: net3, net2
nova boot $vm_params --nic net-id=$net3_id --nic net-id=$net2_id vm6

# vm7: net1, net2, net3
nova boot $vm_params --nic net-id=$net1_id --nic net-id=$net2_id --nic net-id=$net3_id vm7

# vm9: net3
nova boot $vm_params --nic net-id=$net3_id vm9

# vm8: net4
nova boot $vm_params --nic net-id=$net4_id vm8

# show where the vms ended up
nova list --fields name,status,Networks,OS-EXT-SRV-ATTR:host



set +ex
