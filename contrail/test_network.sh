#! /bin/bash
# 
# test_network.sh
#
# Set up a couple of test VMs distributed across a couple of devstack
# contrail nodes with floating ips.
#
# control1 - uses localrc-multinode-server
# compute1 - uses localrc-multinode-compute, with SERVICE_HOST=$IP_OF_CONTROL1
#
#    Devstack                 
#    Contrail nodes           VMS in Contrail nodes
#    --------------           --------------------- 
#    
#    control1                 vm2     
#      eth0                     eth0     
#        192.168.56.119           10.1.0.252     
#      vhost0                     10.99.99.252 (floating)
#      vgw          
#    
#    
#    compute1                 vm1   
#      eth0                     eth0   
#        192.168.56.103           10.1.0.253   
#      vhost0                     10.99.99.253 (floating)
#

set -ex

. ./openrc admin demo

yes | ssh-keygen -N "" -f sshkey
nova keypair-add --pub-key sshkey.pub sshkey


# allow ping and ssh
nova secgroup-list
nova secgroup-list-rules default
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
nova secgroup-list-rules default

# net1
eval $(neutron net-create -f shell -c id net1 | sed -ne '/^id=/p')
net1_id=$id
echo "net1_id=$net1_id"
neutron subnet-create --name net1-subnet1 $net1_id 10.1.0.0/24

# net2 (cloud)
eval $(neutron net-create -f shell -c id net2 | sed -ne '/^id=/p')
net2_id=$id
echo "net2_id=$net2_id"
neutron subnet-create --name net2-subnet1 $net2_id 10.2.0.0/24

# public
eval $(neutron net-create -f shell -c id public | sed -ne '/^id=/p')
public_id=$id
echo "public_id=$public_id"
neutron subnet-create --name public-subnet1 $public_id $CONTRAIL_VGW_PUBLIC_SUBNET --disable-dhcp
python /opt/stack/contrail/controller/src/config/utils/create_floating_pool.py --public_vn_name default-domain:demo:public --floating_ip_pool_name floatingip_pool 
python /opt/stack/contrail/controller/src/config/utils/use_floating_pool.py --project_name default-domain:demo --floating_ip_pool_name default-domain:demo:public:floatingip_pool

# vms

image=cirros-0.3.1-x86_64-uec # default stock image
# try to use a test image instead of stock
IMAGE_NAME=${IMAGE_NAME:-cirros-test}
IMAGE_FILE=${IMAGE_FILE:-~/projects/piston/projects/cirros/cirros-0.3.1-x86_64-nbk.qcow2}
if glance image-show $IMAGE_NAME > /dev/null 2>&1; then
    image=$IMAGE_NAME
else
    if [ -e $IMAGE_FILE ] && 
	glance image-create --name=$IMAGE_NAME --disk-format qcow2  --container-format=bare  < $IMAGE_FILE; then
	image=$IMAGE_NAME
    fi
fi

tee cloudinit.sh <<EOF
#! /bin/sh
echo "Cloudinit worked!"
echo

echo "Inet interfaces:"
ip -f inet -o addr list
EOF
chmod a+x cloudinit.sh


flavor=m1.tiny
base="--image $image --flavor $flavor --key-name sshkey --user-data cloudinit.sh"

# vm1: net1
nova boot $base --nic net-id=$net1_id vm1

# vm2: net2
nova boot $base --nic net-id=$net2_id vm2

# vm3: net1, net2
nova boot $base --nic net-id=$net1_id --nic net-id=$net2_id vm3


# if the net_policy_join script exists, then use it to join net1 and net2
# use ${BASH_SOURCE[0]} instead of $0, because it works when this script is sourced
THIS_DIR=$(dirname ${BASH_SOURCE[0]})
PATH=$THIS_DIR:$PATH
if which net_policy_join.py; then
    net_policy_join.py $net1_id $net2_id 
fi


die() {
    echo "ERROR: " "$@" >&2
    exit 1
}

# create a floating ip, usually on the $public network
floatingip_create() {
    local public_id=$1

    eval $(neutron floatingip-create -f shell -c id $public_id | sed -ne /id=/p || \
	die "couldn't create floatnig ip")
    floatingip_id=$id
    echo $floatingip_id
}

# assign $floatingip_id to $vm_name's interface on $net_name
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

# floatingip1 for vm1,net1
floatingip1_id=$(floatingip_create $public_id)
floatingip_associate vm1 net1 $floatingip1_id
neutron floatingip-show $floatingip1_id

# floatingip2 for vm2,net2
floatingip2_id=$(floatingip_create $public_id)
floatingip_associate vm2 net2 $floatingip2_id
neutron floatingip-show $floatingip2_id

# floatingip3 for vm3,net1
floatingip3_id=$(floatingip_create $public_id)
floatingip_associate vm3 net1 $floatingip3_id
neutron floatingip-show $floatingip3_id

# show where the vms ended up
nova list --fields name,status,Networks,OS-EXT-SRV-ATTR:host

set +ex
