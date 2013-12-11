#! /bin/bash
#
# test_network_complex.sh
#
# test a complex network:
#
#    net1        net2       public       net4
#     |           |           |           |
#     +- vrouter -+           |           |
#     |	       	  +------------- vrouter -+
#     |  1     2  |           |           |
#     +--- vm1 ---+           |           |
#     |           |  2     1  |    vm8 ---+
#     |           +--- vm3 ---+           |
#     |  2     1  |           |           |
#     +--- vm2 ---+           |           |
#     |        f  |  2     1  |           |
#     |           +--- vm6 ---+           |
#     |           |           |           |
#     +-----------------+     |           |
#     |           |     |     |           |
#     |           |    2|     |           |
#     |           +--- vm7 ---+           |
#     |           |  3     1  |           |
#     +--- vm4    |           |           |
#     |           |    vm9 ---+           |
#     |           |           |           |
#     |    vm5----+           |           |
#     |           |           |           |
#
#
# vm1: net1, net2
# vm2: net2, net1, float on net2
# vm4: net1
# vm5: net2
# vm3: public, net2
# vm6: public, net2
# vm7: public, net1, net2
# vm9: public
# vm8: net4

# die on errors
set -ex

# source openrc after stack.sh completes to join the demo project as admin user
. ./openrc admin demo

# add this script's parent directory to the path
THIS_DIR=$(dirname ${BASH_SOURCE[0]})
PATH=$THIS_DIR:$PATH

#----------------------------------------------------------------------
# functions

die() {
    echo "ERROR: " "$@" >&2
    exit 1
}

# create a network with $net_name and return its id
net_create() {
    net_name="$1"
    eval $(neutron net-create -f shell -c id $net_name | sed -ne '/^id=/p' || \
	die "couldn't create network $net_name")
    echo $id
}

# floatingip_create net_id
#
# create a floating ip on a network.  the network must have a
# floatingip pool created for it.  see create_floating_pool.py
#
floatingip_create() {
    local net_id=$1

    eval $(neutron floatingip-create -f shell -c id $net_id | sed -ne /id=/p || \
	die "couldn't create floating ip")
    echo $id
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


#----------------------------------------------------------------------
# create vms and network

# secgroup allow ping and ssh
nova secgroup-list
nova secgroup-list-rules default
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
nova secgroup-list-rules default

# net1
net1_id=$(net_create net1)
neutron subnet-create --name net1-subnet1 $net1_id 10.1.0.0/24

# net2 (cloud)
net2_id=$(net_create net2)
echo "net2_id=$net2_id"
neutron subnet-create --name net2-subnet1 $net2_id 10.2.0.0/24

# public (public)
public_id=$(net_create public)
echo "public_id=$public_id"
# CONTRAIL_VGW_PUBLIC_SUBNET is set in localrc to be publicly addressable ips
neutron subnet-create --name public-subnet1 $public_id $CONTRAIL_VGW_PUBLIC_SUBNET --disable-dhcp

# call contrail to create floating ip pool
python /opt/stack/contrail/controller/src/config/utils/create_floating_pool.py --public_vn_name default-domain:demo:public --floating_ip_pool_name floatingip_pool
python /opt/stack/contrail/controller/src/config/utils/use_floating_pool.py --project_name default-domain:demo --floating_ip_pool_name default-domain:demo:public:floatingip_pool

# route between net1 and net2
net_policy_join.py $net1_id $net2_id

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
ssh-add sshkey
nova keypair-add --pub-key sshkey.pub sshkey

# cloudinit script to verify that the metadata server is working
tee cloudinit.sh <<EOF
#! /bin/sh
echo "Cloudinit worked!"
echo

echo "Inet interfaces:"
ip -o -f inet addr list
EOF
chmod a+x cloudinit.sh

# vm parameters
flavor=m1.tiny
vm_params="--image $image --flavor $flavor --key-name sshkey --user-data cloudinit.sh"

# vms

# vm1: net1, net2
nova boot $vm_params --nic net-id=$net1_id --nic net-id=$net2_id vm1

# vm2: net2, net1, float on net2
nova boot $vm_params --nic net-id=$net2_id --nic net-id=$net1_id vm2

# floatingip1 for vm2,net2
floatingip1_id=$(floatingip_create $public_id)
floatingip_associate vm2 net2 $floatingip1_id

# vm4: net1
nova boot $vm_params --nic net-id=$net1_id vm4

# vm5: net2
nova boot $vm_params --nic net-id=$net2_id vm5

# vm3: public, net2
nova boot $vm_params --nic net-id=$public_id --nic net-id=$net2_id vm3

# vm6: public, net2
nova boot $vm_params --nic net-id=$public_id --nic net-id=$net2_id vm6

# vm7: public, net1, net2
nova boot $vm_params --nic net-id=$public_id --nic net-id=$net1_id --nic net-id=$net2_id vm7

# vm9: public
nova boot $vm_params --nic net-id=$public_id vm9

# net4 (new)
net4_id=$(net_create net4)
echo "net4_id=$net4_id"
neutron subnet-create --name net4-subnet1 $net4_id 10.4.0.0/24

# allow traffic between net2 and net4
net_policy_join.py $net2_id $net4_id

# vm8: net4
nova boot $vm_params --nic net-id=$net4_id vm8

# show where the vms ended up
nova list --fields name,status,Networks,OS-EXT-SRV-ATTR:host

# restore the shell flags, since this script is usually sourced
set +ex
