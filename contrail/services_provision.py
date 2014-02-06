"""
NAME

contrail_veth_port - create a veth interface connected to a Contrail virtual network

SYNOPSIS

  contrail_veth_port [options] instance network

DESCRIPTION

Creates a veth interface that's connected to a Contrail virtual
network.  This lets you run programs on the local host that can
connect directly to a virtual network.  You can ssh directly into VMs
or provide servers on the local host that VMs can connect to.  

USAGE:

  contrail_veth_port [options] instance_name network_name

  instance -- the name to use for the virtual instance.
  
  network -- the name of the network to connect to

OPTIONS

  --netns      -- network namespace to put the veth interface into.
                  defaults to the same as the network.

  --api-server -- Contrail API server.  default: 127.0.0.1

  --api-port   -- Contrail API port.  default: 8082

  --project    -- Contrail tenant/project.  default: default-domain:default-project
  
OUTPUT

  port_id: UUID of created port, useful for neutron commands like floatingip-associate
  port_fqdn: 
  port_ip
  port_hw
  port_gateway
  port_dns
  port_netns

EXAMPLES

  * create a veth port
  
  contrail_veth_port my_instance my_net

  * delete the veth port

  contrail_veth_port --delete my_instance

  # use the veth to ssh into a VM
  sudo ip netns exec my_net ssh $my_vm_ip

BUGS  

This assumes there's only one subnet on the network.  If there is more
than one, this will choose the first subnet and set the namespace's
default route and DNS from it.
  
AUTHOR

  Noel Burton-Krahn <noel@pistoncloud.com>
  Feb 5, 2014

"""
__docformat__ = "restructuredtext en"

import sys
import re
import os
import netaddr
import argparse

# KLUDGE - should be in PYTHONPATH
sys.path.append('/opt/stack/nova/plugins/contrail')

# api for talking to contrail system-global API server
from vnc_api import vnc_api

# api for talking to local host's contrail vrouter
import instance_service.ttypes
from contrail_utils import vrouter_rpc, uuid_from_string, new_interface_name, sudo

class ServicesProvisioner(object):
    """
    add an interface to the services network
    """
    
    def __init__(self, argv):
        parser = argparse.ArgumentParser()
        self.parser = parser
        defaults = {
            'api-server': '127.0.0.1',
            'port': '8082',
            'network': 'default-domain:default-project:default-network',
            'project': 'default-domain:default-project'
            }
        parser.set_defaults(**defaults)
        parser.add_argument(
            "-s", "--api-server", help="API server address")
        parser.add_argument(
            "-p", "--port", help="API server port")
        parser.add_argument(
            "-n", "--network", help="Virtual-network")
        parser.add_argument(
            "--subnet", help="IP subnet address for the virtual-network")
        parser.add_argument(
            "--project", help="OpenStack project name")
        parser.add_argument(
            "--add", action="store_true", help="Add instance")
        parser.add_argument(
            "--delete", action="store_true", help="Delete instance")
        parser.add_argument(
            "instance", help="Instance name")

        if argv is not None:
            arguments = parser.parse_args(argv)
            self.init_dict(arguments)
            
    def init_dict(self, arguments):
        self.arguments = arguments
        self.client = vnc_api.VncApi(api_server_host=arguments.api_server,
                                     api_server_port=arguments.port)
        self.network_name = arguments.network
        self.project = arguments.project

    def virtual_machine_find(self, vm_name):
        """raises vnc_api.NoIdError if vm_name doesn't exist"""
        return self.client.virtual_machine_read(fq_name = [vm_name])

    def virtual_machine_find_or_create(self, vm_name):
        try:
            vm_instance = self.virtual_machine_find(vm_name)
        except vnc_api.NoIdError:
            vm_instance = vnc_api.VirtualMachine(vm_name)
            self.client.virtual_machine_create(vm_instance)
        return vm_instance

    def virtual_machine_delete(self, vm_instance):
        self.client.virtual_machine_delete(id = vm_instance.uuid)

    def virtual_network_find_or_create(self, network_name, subnet):
        fq_name = network_name.split(':')
        try:
            return self.client.virtual_network_read(fq_name = fq_name)
        except vnc_api.NoIdError:
            pass

        if not subnet:
            print "%s does not exist" %  network_name
            print "Please specify a subnet IP address in order to create virtual-network"
            return None

        vnet = vnc_api.VirtualNetwork(fq_name[-1], parent_type = 'project',
                                      fq_name = fq_name)

        ipam = self.client.network_ipam_read(
            fq_name = ['default-domain',
                       'default-project',
                       'default-network-ipam'])

        (prefix, plen) = subnet.split('/')
        subnet = vnc_api.IpamSubnetType(subnet = vnc_api.SubnetType(prefix, int(plen)))
        vnet.add_network_ipam(ipam, vnc_api.VnSubnetsType([subnet]))

        self.client.virtual_network_create(vnet)
        return vnet

    def vmi_update(self, vm_instance):
        fq_name = vm_instance.fq_name
        fq_name.append('0')
        create = False
        try:
            vmi = self.client.virtual_machine_interface_read(fq_name = fq_name)
        except vnc_api.NoIdError:
            vmi = vnc_api.VirtualMachineInterface(parent_type = 'virtual-machine',
                                                  fq_name = fq_name)
            create = True

        vnet = self.virtual_network_find_or_create(self.network_name, self.subnet)
        if not vnet:
            raise ValueError("must be able to find or create vnet (%s, %s)" % (self.network_name, self.subnet))

        vmi.set_virtual_network(vnet)
        if create:
            self.client.virtual_machine_interface_create(vmi)
        else:
            self.client.virtual_machine_interface_update(vmi)
        # re-read the vmi to get its mac addresses
        vmi = self.client.virtual_machine_interface_read(fq_name = fq_name)

        ips = vmi.get_instance_ip_back_refs()
        if ips and len(ips):
            uuid = ips[0]['uuid']
        else:
            ip = vnc_api.InstanceIp(vm_instance.name + '.0')
            ip.set_virtual_machine_interface(vmi)
            ip.set_virtual_network(vnet)
            uuid = self.client.instance_ip_create(ip)

        ip = self.client.instance_ip_read(id=uuid)

        print "IP address: %s" % ip.get_instance_ip_address()
        return vmi

    def vmi_clean(self, vm_instance):
        fq_name = vm_instance.fq_name
        fq_name.append('0')
        try:
            vmi = self.client.virtual_machine_interface_read(fq_name = fq_name)
        except vnc_api.NoIdError:
            return

        ips = vmi.get_instance_ip_back_refs()
        for ref in ips:
            self.client.instance_ip_delete(id = ref['uuid'])

        self.client.virtual_machine_interface_delete(id = vmi.uuid)

    def plug_veth(self, vm_instance, vmi, netns):

        # sanitize netns since it gets passed to the shell
        if not re.match(r'^[-.\w]+$', netns):
            raise ValueError("netns=[%s] must be a valid namespace name (a single word)" % netns)
        
        """plug vmi into a veth pair, and put one end of the pair in the network namespace"""
        # get the ip, mac, and gateway from the vmi
        ip_uuid = vmi.get_instance_ip_back_refs()[0]['uuid']
        ip = self.client.instance_ip_read(id=ip_uuid).get_instance_ip_address()
        mac = vmi.virtual_machine_interface_mac_addresses.mac_address[0]
        net_uuid = vmi.get_virtual_network_refs()[0]['uuid']
        net = self.client.virtual_network_read(id=net_uuid)
        ipam_uuid = net.network_ipam_refs[0]['uuid']
        ipam = self.client.network_ipam_read(id=ipam_uuid)
        # find the netref that matches my net_uuid
        netrefs = ipam.get_virtual_network_back_refs()
        netref = filter(lambda x: x['uuid'] == net_uuid, netrefs)
        if len(netref) != 1:
            raise ValueError("API error: ambiguous netrefs=%s" % (netrefs,))
        netref = netref[0]
        subnets = netref['attr']['ipam_subnets']
        def match_subnet(subnet):
            netmask = "%s/%s" % (subnet['subnet']['ip_prefix'],
                                 subnet['subnet']['ip_prefix_len'])
            return netaddr.IPAddress(ip) in netaddr.IPNetwork(netmask)
        subnet = filter(match_subnet, subnets)
        if len(subnet) != 1:
            raise ValueError("API error: ambiguous subnets=%s for ip=%s" % (subnets,ip))
        subnet = subnet[0]
        gw = subnet['default_gateway']
        netmask = "%s/%s" % (subnet['subnet']['ip_prefix'],
                             subnet['subnet']['ip_prefix_len'])
        netmask = str(netaddr.IPNetwork(netmask).netmask)

        # set up the veth pair with on part for vrouter and one for the netns
        veth_vrouter = new_interface_name(net_uuid, "ve1")
        veth_host = new_interface_name(net_uuid, "ve0")
        sudo("ip link add %s type veth peer name %s" % (veth_vrouter, veth_host))
        sudo("ip netns add %s" % (netns,), check_exit_code=False)
        sudo("ip link set %s netns %s" % (veth_host, netns))
        sudo("ip netns exec %s ifconfig %s hw ether %s" % (netns, veth_host, mac))
        sudo("ip netns exec %s ifconfig %s %s netmask %s" % (netns, veth_host, ip, netmask))
        sudo("ip netns exec %s route add default gw %s" % (netns, gw))
        sudo("ifconfig %s up" % (veth_vrouter,))

        resolv_conf = "/etc/netns/%s/resolv.conf" % netns
        os.makedirs(os.path.dirname(resolv_conf))
        with open(resolv_conf, "w") as f:
            f.write("nameserver %s\n" % gw)

        port = instance_service.ttypes.Port(
            uuid_from_string(vmi.uuid),
            uuid_from_string(vm_instance.uuid), 
            veth_vrouter,
            ip,
            uuid_from_string(net.uuid),
            mac,
            )
        rpc = vrouter_rpc()
        rpc.AddPort([port])
        return port

    def unplug(self, vmi):
        rpc = rpc_client_instance()
        rpc.DeletePort(uuid_from_string(vmi))
        # TODO - how to find the old interface name and delete it?
       
        
if __name__ == '__main__':
    provisioner = ServicesProvisioner(sys.argv[1:])
    arguments = provisioner.arguments
    
    if arguments.add:
        vm_instance = provisioner.virtual_machine_find_or_create(arguments.instance)
        vmi = provisioner.vmi_update(vm_instance)
        provisioner.plug(vm_instance, vmi)
    elif arguments.delete:
        vm_instance = provisioner.virtual_machine_find(arguments.instance)
        provisioner.vmi_clean(vm_instance)
        provisioner.virtual_machine_delete(vm_instance)
    else:
        assert "Please specify one of --add or --delete"

