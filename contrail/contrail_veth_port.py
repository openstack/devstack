#! /usr/bin/env python
"""
NAME

contrail_veth_port - create a veth interface to a Contrail virtual
                     network

DESCRIPTION

Usually VMs are connected to virtual network ports.  This creates a
veth interface on the local host that's connected to a Contrail
virtual network.  Local programs (like ssh) can connect directly to
VMs, and VMs can connect to local servers (like mysql).

USAGE

  contrail_veth_port [options] vm_name network_name

  contrail_veth_port --delete vm_name

Or, from python:

  from contrail_veth_port import ContrailVethPort
  ret = ContrailVethPort(net_name="mynet", vm_name="myvm").create()
  ret = ContrailVethPort(vm_name="myvm").delete()

OUTPUT

Outputs a set of variables in json, shell, table, or python format
(see --format):

  port_id
    UUID of created port, useful for neutron commands like
    floatingip-associate

  veth
    name of veth interface created
  
  netns
    network namesace veth is in
    
  ip
    IP address of veth interface
  hw
    Ether address of veth interface

  gateway
    IP address of veth default gateway
  
  dns
    IP address of veth DNS server
    

EXAMPLES

* create a veth port
  
  contrail_veth_port my_instance my_net

* delete the veth port

  contrail_veth_port --delete my_instance

* use the veth to ssh into a VM

  sudo ip netns exec my_net ssh $my_vm_ip

BUGS  

This assumes there's only one subnet on the network.  If there is more
than one, this will choose the first subnet and set the namespace's
default route and DNS from the first subnet.

--delete doesn't delete the veth interfaces or netns.  We need an
extension to the vrouter API to retrieve the name of the interface a
port is bound to.
  
AUTHOR

  Noel Burton-Krahn <noel@pistoncloud.com>

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
from contrail_utils import vrouter_rpc, \
     uuid_from_string, uuid_array_to_str, \
     new_interface_name, sudo, link_exists_func, ProcessExecutionError, \
     format_dict

class ContrailVethPort(object):
    """Create a veth port connected to a Contrail virtual network"""
    
    def __init__(self, *argv, **args):
        """Set arguments dict.  If args is not a dict, then parse it
        as an array of strings, or sys.argv if None"""

        # set args from kw arguments or parse argv (defaulting to
        # sys.argv)
        if args:
            self.args = args
        else:
            if not argv:
                argv = None
            self.args = vars(self.argparser().parse_args(argv))
            
        self.vnc_client = None

    @classmethod
    def argparser(cls):
        """Return an argparse.ArgumentParser for me"""
        parser = argparse.ArgumentParser(__doc__)
        parser.add_argument(
            "--api-server",
            default=os.environ.get('SERVICE_HOST', '127.0.0.1'),
            help=("API server address."
                  + "  Default: SERVICE_HOST from env or 127.0.0.1"))
        parser.add_argument(
            "--api-port",
            default=os.environ.get('CONTRAIL_API_PORT', '8082'),
            help=("API server port."
                  + "  Default: CONTRAIL_API_PORT from env or 8082"))
        parser.add_argument(
            "--project",
            default=os.environ.get('CONTRAIL_PROJECT',
                                   'default-domain:default-project'),
            help=("OpenStack project name."
                  + "  Default: CONTRAIL_PROJECT"
                  + " or default-domain:default-project"))
        parser.add_argument(
            "--delete", action="store_true",
            help="Delete the virtual machine and network")
        parser.add_argument(
            "--format",
            default="table",
            help="Format of output values: table, shell, json, python")
        parser.add_argument(
            "--subnet",
            help=("IP subnet address for the virtual-network"
                  + ", if the network doesn't already exist"))
        parser.add_argument(
            "--netns",
            help=("Name of the network namespace to put the veth interface in."
                  + "   Default: virtual network name"))
        parser.add_argument(
            "vm_name", help="Name of virtual machine to create to own the port")
        parser.add_argument(
            "net_name", default=None,
            help=("Name of virtual network to attach veth interface to."
                  + "  Will be created if it doesn't already exist"))
        return parser

    def vnc_connect(self):
        """open a connection to the Contrail API server"""
        if not self.vnc_client:
            self.vnc_client = vnc_api.VncApi(
                api_server_host=self.args['api_server'],
                api_server_port=self.args['api_port'])
        return self.vnc_client
        
    def create(self):
        """Create a vm and vmi, find or create a network, and attach
        the vmi to a new veth interface

        Arguments:

          vm_name   name of the vm to create
          net_name  name of the netwok to arrach to
          subnet    x.x.x.x/len - optional if network already exists
          netns     Network namespace where the veth interface is bound to.  Defaults to net_name    

        Returns:

          A dict with the following elements:
          
          port_id  uuid of port
          ip
          veth     name of veth interface
          netns    Network namespace where the veth interface is bound to
          
        """
        
        # remember what to clean up if things go wrong
        port_created = False
        veth_created = False
        netns_created = False
        ip_created = False
        vmi_created = False
        vnet_created = False
        vm_created = False

        try:
            # sanity check
            net_name = self.args.get('net_name')
            if not net_name:
                raise ValueError("Network name argument is required")

            # sanitize netns since it gets passed to the shell
            netns = self.args.get('netns')
            if not netns:
                netns = net_name
            if not re.match(r'^[-.\w]+$', netns):
                raise ValueError("netns=[%s] must be a valid namespace name"
                                 + " (a single word)" % netns)

            
            vnc_client = self.vnc_connect()

            proj_fq_name = self.args['project'].split(':')

            # find or create the VM
            vm_fq_name = proj_fq_name + [ self.args['vm_name'] ]

            # debug
            #import pdb; pdb.set_trace()

            try:
                vm = vnc_client.virtual_machine_read(fq_name = vm_fq_name)
                if vm:
                    raise ValueError(("Virtual machine named %s already exists."
                                      + "  Use --delete to delete it")
                                     % self.args['vm_name'])
            except vnc_api.NoIdError:
                # create vm if necessary
                vm = vnc_api.VirtualMachine(':'.join(vm_fq_name),
                                            fq_name=vm_fq_name)
                vnc_client.virtual_machine_create(vm)
                vm = vnc_client.virtual_machine_read(fq_name = vm_fq_name)
                vm_created = True
                
            # find or create the network
            vnet_fq_name = proj_fq_name + [ net_name ]
            vnet_created = False
            try:
                vnet = vnc_client.virtual_network_read(fq_name = vnet_fq_name)
            except vnc_api.NoIdError:
                # create the network if it doesn't exist
                vnet = vnc_api.VirtualNetwork(vnet_fq_name[-1],
                                              parent_type = 'project',
                                              fq_name = vnet_fq_name)

                # add a subnet
                ipam = vnc_client.network_ipam_read(
                    fq_name = ['default-domain',
                               'default-project',
                               'default-network-ipam'])
                (prefix, plen) = self.args['subnet'].split('/')
                subnet = vnc_api.IpamSubnetType(
                    subnet = vnc_api.SubnetType(prefix, int(plen)))
                vnet.add_network_ipam(ipam, vnc_api.VnSubnetsType([subnet]))

                vnc_client.virtual_network_create(vnet)
                vnet_created = True

            # find or create the vmi
            vmi_fq_name = vm.fq_name + ['0']
            vmi_created = False
            try:
                vmi = vnc_client.virtual_machine_interface_read(
                    fq_name = vmi_fq_name)
            except vnc_api.NoIdError:
                vmi = vnc_api.VirtualMachineInterface(
                    parent_type = 'virtual-machine',
                    fq_name = vmi_fq_name)
                vmi_created = True
            vmi.set_virtual_network(vnet)
            if vmi_created:
                vnc_client.virtual_machine_interface_create(vmi)
            else:
                vnc_client.virtual_machine_interface_update(vmi)
            # re-read the vmi to get its mac addresses
            vmi = vnc_client.virtual_machine_interface_read(
                fq_name = vmi_fq_name)
            # create an IP for the VMI if it doesn't already have one
            ips = vmi.get_instance_ip_back_refs()
            if not ips:
                ip = vnc_api.InstanceIp(vm.name + '.0')
                ip.set_virtual_machine_interface(vmi)
                ip.set_virtual_network(vnet)
                ip_created = vnc_client.instance_ip_create(ip)

            # Create the veth port.  Create a veth pair.  Put one end
            # in the VMI port and the other in a network namespace
            
            # get the ip, mac, and gateway from the vmi
            ip_uuid = vmi.get_instance_ip_back_refs()[0]['uuid']
            ip = vnc_client.instance_ip_read(id=ip_uuid).instance_ip_address
            mac = vmi.virtual_machine_interface_mac_addresses.mac_address[0]
            subnet = vnet.network_ipam_refs[0]['attr'].ipam_subnets[0]
            gw = subnet.default_gateway
            dns = gw # KLUDGE - that's the default, but some networks
                     # have other DNS configurations
            ipnetaddr = netaddr.IPNetwork("%s/%s" %
                                          (subnet.subnet.ip_prefix,
                                           subnet.subnet.ip_prefix_len))
            
            # set up the veth pair with one part for vrouter and one
            # for the netns

            # find a name that's not already used in the default or
            # netns namespaces
            link_exists = link_exists_func('', netns)
            veth_vrouter = new_interface_name(suffix=vnet.uuid, prefix="ve1",
                                              exists_func=link_exists)
            veth_host = new_interface_name(suffix=vnet.uuid, prefix="ve0",
                                           exists_func=link_exists)
            
            sudo("ip link add %s type veth peer name %s",
                 (veth_vrouter, veth_host))
            veth_created = True
            try:
                sudo("ip netns add %s", (netns,))
                netns_created = True
            except ProcessExecutionError:
                pass
            
            sudo("ip link set %s netns %s",
                 (veth_host, netns))
            sudo("ip netns exec %s ip link set dev %s address %s",
                 (netns, veth_host, mac))
            sudo("ip netns exec %s ip address add %s broadcast %s dev %s",
                 (netns,
                  ("%s/%s" % (ip, subnet.subnet.ip_prefix_len)),
                  ipnetaddr.broadcast, veth_host))
            sudo("ip netns exec %s ip link set dev %s up",
                 (netns, veth_host))
            sudo("ip netns exec %s route add default gw %s dev %s",
                 (netns, gw, veth_host))
            sudo("ip link set dev %s up", (veth_vrouter,))

            # make a namespace-specific resolv.conf
            resolv_conf = "/etc/netns/%s/resolv.conf" % netns
            resolv_conf_body = "nameserver %s\n" % dns
            sudo("mkdir -p %s", (os.path.dirname(resolv_conf),))
            sudo("tee %s", (resolv_conf,), process_input=resolv_conf_body)

            # finally, create the Contrail port
            port = instance_service.ttypes.Port(
                uuid_from_string(vmi.uuid),
                uuid_from_string(vm.uuid), 
                veth_vrouter,
                ip,
                uuid_from_string(vnet.uuid),
                mac,
                )
            rpc = vrouter_rpc()
            rpc.AddPort([port])
            port_created = True
            
            return(dict(
                port_id = uuid_array_to_str(port.port_id),
                vm_id = vm.uuid,
                net_id = vnet.uuid,
                vmi_id = vmi.uuid,
                veth = veth_host,
                netns = netns,
                ip = ip,
                mac = mac,
                gw = gw,
                dns = dns,
                netmask = str(ipnetaddr.netmask),
                broadcast = str(ipnetaddr.broadcast),
                ))

        except:
            # something went wrong, clean up
            if port_created:
                rpc.DeletePort(port.port_id)
            if veth_created:
                sudo("ip link delete %s", (veth_vrouter,),
                     check_exit_code=False)
            if netns_created:
                sudo("ip netns delete %s", (netns,), check_exit_code=False)
            if ip_created:
                vnc_client.instance_ip_delete(id=ip_created)
            if vmi_created:
                vnc_client.virtual_machine_interface_delete(id=vmi.uuid)
            if vnet_created:
                vnc_client.virtual_network_delete(id=vnet.uuid)
            if vm_created:
                vnc_client.virtual_machine_delete(id=vm.uuid)
            raise

    def delete(self):
        """Delete a vm and its vmi."""
        vnc_client = self.vnc_connect()
        
        proj_fq_name = self.args.get('project').split(':')
        vm_fq_name = proj_fq_name + [ self.args.get('vm_name') ]
        try:
            # delete all dependent VMIs and IPs then delete the VM
            vm = vnc_client.virtual_machine_read(fq_name = vm_fq_name)
            for vmi in vm.get_virtual_machine_interfaces():
                try:
                    vmi = vnc_client.virtual_machine_interface_read(
                        id=vmi['uuid'])
                    for ip in vmi.get_instance_ip_back_refs():
                        try:
                            vnc_client.instance_ip_delete(id=ip['uuid'])
                        except vnc_api.NoIdError:
                            pass
                    vnc_client.virtual_machine_interface_delete(id=vmi.uuid)
                except vnc_api.NoIdError:
                    pass
            vnc_client.virtual_machine_delete(id=vm.uuid)
        except vnc_api.NoIdError:
            pass

        # TODO: delete the veth, but there's no way to find the local
        # vrouter port.  The vrouter API has AddPort and DeletePort,
        # but no GetPort
    
    def main(self):
        """run from command line"""
        if self.args.get('delete'):
            self.delete()
        else:
            ret = self.create()
            print format_dict(ret, self.args.get('format'))

if __name__ == '__main__':
    ContrailVethPort().main()

