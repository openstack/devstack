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

set -eux

. ./openrc admin demo

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
image=cirros-0.3.1-x86_64-uec
flavor=m1.tiny
base="--image $image --flavor $flavor"

# vm1: net1
#nova boot $base --nic net-id=$net1_id --nic net-id=$net2_id vm1
nova boot $base --nic net-id=$net1_id vm1

# vm2: net1
nova boot $base --nic net-id=$net1_id vm2

# floatingip for vm1
eval $(neutron floatingip-create -f shell -c id $public_id | sed -ne /id=/p)
floatingip1_id=$id
vm1_net1_ip=$(nova show vm1 | sed -ne 's/^| net1 network[ \t]*|[ \t]*\([.0-9]*\)[ \t]*|/\1/p')
port_id=$(neutron port-list | sed -ne 's/| \([-0-9a-f]*\)[ \t]*|[ \t]*.*'"$vm1_net1_ip"'.*/\1/p')
neutron floatingip-associate $floatingip1_id $port_id
neutron floatingip-show $floatingip1_id

# floatingip for vm2
eval $(neutron floatingip-create -f shell -c id $public_id | sed -ne /id=/p)
floatingip2_id=$id
vm2_net1_ip=$(nova show vm2 | sed -ne 's/^| net1 network[ \t]*|[ \t]*\([.0-9]*\)[ \t]*|/\1/p')
port_id=$(neutron port-list | sed -ne 's/| \([-0-9a-f]*\)[ \t]*|[ \t]*.*'"$vm2_net1_ip"'.*/\1/p')
neutron floatingip-associate $floatingip2_id $port_id
neutron floatingip-show $floatingip2_id

# show where the vms ended up
nova list --fields name,status,Networks,OS-EXT-SRV-ATTR:host
