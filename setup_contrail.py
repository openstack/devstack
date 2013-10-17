import argparse
import ConfigParser

import platform
import os
import sys
import time
import re
import string
import socket
import netifaces, netaddr
import subprocess
import fnmatch
import struct
import shutil
import json
from pprint import pformat
import xml.etree.ElementTree as ET
import platform
import getpass
import re

import tempfile

# Get Environment Stuff
password = os.environ['ADMIN_PASSWORD'] or 'contrail123'
admin_username = os.environ['CONTRAIL_ADMIN_USERNAME'] or 'admin'
admin_token = os.environ['SERVICE_TOKEN'] or 'contrail123'
admin_tenant = os.environ['CONTRAIL_ADMIN_TENANT'] or 'admin'

# TODO following keystone credentials hardcoded
ks_admin_user = admin_username
ks_admin_password = admin_token
ks_admin_tenant_name = admin_tenant

from contrail_config_templates import *

class Setup(object):
    def __init__(self, args_str = None):
        self._args = None
        if not args_str:
            args_str = ' '.join(sys.argv[1:])
        self._parse_args(args_str)

        self._setup_tgt_path = os.path.abspath(os.path.dirname(sys.argv[0]))

        self._temp_dir_name = tempfile.mkdtemp()
        self._fixed_qemu_conf = False
    #end __init__

    def _parse_args(self, args_str):
        '''
        Eg. python setup.py --cfgm_ip 127.0.0.1 
        '''

        # Source any specified config/ini file
        # Turn off help, so we print all options in response to -h
        conf_parser = argparse.ArgumentParser(add_help = False)
        
        conf_parser.add_argument("-c", "--conf_file",
                                 help="Specify config file", metavar="FILE")
        args, remaining_argv = conf_parser.parse_known_args(args_str.split())

        global_defaults = {
            'use_certs': False,
            'puppet_server': None,
        }
        cfgm_defaults = {
            'cfgm_ip': '127.0.0.1',
            'openstack_ip': '127.0.0.1',
            'service_token': '',
            'multi_tenancy': False,
        }
        openstack_defaults = {
            'cfgm_ip': '127.0.0.1',
            'service_token': '',
        }
        control_node_defaults = {
            'cfgm_ip': '127.0.0.1',
            'collector_ip': '127.0.0.1',
            'control_ip': '127.0.0.1',
        }
        compute_node_defaults = {
            'compute_ip': '127.0.0.1',
            'openstack_ip': '127.0.0.1',
            'service_token': '',
            'ncontrols' : 2,
            'physical_interface': None,
            'non_mgmt_ip': None,
            'non_mgmt_gw': None,
        }
        collector_defaults = {
            'cfgm_ip': '127.0.0.1',
            'self_collector_ip': '127.0.0.1',
        }
        database_defaults = {
            'database_dir' : '/usr/share/cassandra',
            'database_listen_ip' : '127.0.0.1',                     
        }

        if args.conf_file:
            config = ConfigParser.SafeConfigParser()
            config.read([args.conf_file])
            global_defaults.update(dict(config.items("GLOBAL")))
            cfgm_defaults.update(dict(config.items("CFGM")))
            openstack_defaults.update(dict(config.items("OPENSTACK")))
            control_node_defaults.update(dict(config.items("CONTROL-NODE")))
            compute_node_defaults.update(dict(config.items("COMPUTE-NODE")))
            collector_defaults.update(dict(config.items("COLLECTOR")))
            database_defaults.update(dict(config.items("DATABASE")))

        # Override with CLI options
        # Don't surpress add_help here so it will handle -h
        parser = argparse.ArgumentParser(
            # Inherit options from config_parser
            parents=[conf_parser],
            # print script description with -h/--help
            description=__doc__,
            # Don't mess with format of description
            formatter_class=argparse.RawDescriptionHelpFormatter,
            )

        all_defaults = {'global': global_defaults,
                        'cfgm': cfgm_defaults,
                        'openstack': openstack_defaults,
                        'control-node': control_node_defaults,
                        'compute-node': compute_node_defaults,
                        'collector': collector_defaults,
                        'database': database_defaults,
                       }
        parser.set_defaults(**all_defaults)

        parser.add_argument("--role", action = 'append', 
                            help = "Role of server (config, openstack, control, compute, collector, webui, database")
        parser.add_argument("--cfgm_ip", help = "IP Address of Configuration Node")
        parser.add_argument("--openstack_ip", help = "IP Address of Openstack Node")
        parser.add_argument("--openstack_mgmt_ip", help = "Management IP Address of Openstack Node")
        parser.add_argument("--collector_ip", help = "IP Address of Collector Node")
        parser.add_argument("--discovery_ip", help = "IP Address of Discovery Node")
        parser.add_argument("--control_ip", help = "IP Address of first Control Node (for control role)")
        parser.add_argument("--ncontrols", help = "Number of Control Nodes in the system (for compute role)")
        parser.add_argument("--compute_ip", help = "IP Address of Compute Node (for compute role)")
        parser.add_argument("--service_token", help = "The service password to access keystone")
        parser.add_argument("--physical_interface", help = "Name of the physical interface to use")
        parser.add_argument("--non_mgmt_ip", help = "IP Address of non-management interface(fabric network) on the compute  node")
        parser.add_argument("--non_mgmt_gw", help = "Gateway Address of the non-management interface(fabric network) on the compute node")
        parser.add_argument("--use_certs", help = "Use certificates for authentication",
            action="store_true")
        parser.add_argument("--puppet_server", help = "FQDN of Puppet Master")
        parser.add_argument("--multi_tenancy", help = "Enforce resource permissions (implies keystone token validation)",
            action="store_true")
        parser.add_argument("--cassandra_ip_list", help = "IP Addresses of Cassandra Nodes", nargs = '+', type = str)
        parser.add_argument("--database_listen_ip", help = "Listen IP Address of database node", default = '127.0.0.1')
        parser.add_argument("--database_dir", help = "Directory where database binary exists", default = '/usr/share/cassandra')
        parser.add_argument("--database_initial_token", help = "Initial token for database node")
        parser.add_argument("--database_seed_list", help = "List of seed nodes for database", nargs='+')
        parser.add_argument("--num_collector_nodes", help = "Number of Collector Nodes", type = int)
        parser.add_argument("--redis_master_ip", help = "IP Address of Redis Master Node")
        parser.add_argument("--redis_role", help = "Redis Role of Node")
        parser.add_argument("--self_collector_ip", help = "Self IP of Collector Node")
    
        self._args = parser.parse_args(remaining_argv)

        if self._args.physical_interface:
            self._args.cfgm_ip = self.get_intf_ip(self._args.physical_interface)
        print 'Using IP address %s' % self._args.cfgm_ip

        # dsetia
        self._args.openstack_ip = self._args.cfgm_ip
        self._args.collector_ip = self._args.cfgm_ip
        self._args.discovery_ip = self._args.cfgm_ip
        self._args.control_ip = self._args.cfgm_ip
        self._args.compute_ip = self._args.cfgm_ip
        self._args.openstack_mgmt_ip = self._args.cfgm_ip
        self._args.database_listen_ip = self._args.cfgm_ip
        self._args.cassandra_ip_list = ['127.0.0.1']
        self._args.role = ['config', 'openstack', 'control', 'compute', 'collector']

    #end _parse_args

    def call_cmd(self, cmd):
        from subprocess import call
        return call(cmd, shell=True)
    # end

    def run_cmd(self, cmd):
        """Return (status, output) of executing cmd in a shell."""
        pipe = os.popen('{ ' + cmd + '; } 2>&1', 'r')
        text = ''
        while True:
            line = pipe.readline()
            if line == '':
                break
            text += line
            print line
        sts = pipe.close()
        if sts is None: sts = 0
        if text[-1:] == '\n': text = text[:-1]
        return sts, text
    # end

    def run_shell (self, cmd):
        s, o = self.run_cmd (cmd)
        # if s: raise RuntimeError, '+ %s[%d]\n%s' % (cmd, s, o)
        print '+ %s [%d]' % (cmd, s)
        return o

    def _template_substitute(self, template, vals):
        data = template.safe_substitute(vals)
        return data
    #end _template_substitute

    def _template_substitute_write(self, template, vals, filename):
        data = self._template_substitute(template, vals)
        outfile = open(filename, 'w')
        outfile.write(data)
        outfile.close()
    #end _template_substitute_write

    def _replaces_in_file(self, file, replacement_list):
        rs = [ (re.compile(regexp), repl) for (regexp, repl) in replacement_list]
        file_tmp = file + ".tmp"
        with open(file, 'r') as f:
            with open(file_tmp, 'w') as f_tmp:
                for line in f:
                    for r, replace in rs:
                        match = r.search(line)
                        if match:
                            line = replace + "\n"
                    f_tmp.write(line)
        shutil.move(file_tmp, file)
    #end _replaces_in_file

    def replace_in_file(self, file, regexp, replace):
        self._replaces_in_file(file, [(regexp, replace)])
    #end replace_in_file    
        
    def find_gateway (self, dev):
        gateway = ''
        gateway = self.run_shell("netstat -rn | grep ^\"0.0.0.0\" | grep %s | awk '{ print $2 }'" % dev)
                # capture = True).strip()
        return gateway

    #end find_gateway

    def get_dns_servers (self, dev):
        dns_list = self.run_shell("grep \"^nameserver\\>\" /etc/resolv.conf | awk  '{print $2}'")
        return dns_list.split()
    #end get_dns_servers

    def get_domain_search_list (self):
        domain_list = ''
        domain_list = self.run_shell("grep ^\"search\" /etc/resolv.conf | awk '{$1=\"\";print $0}'")
        if not domain_list:
            domain_list = self.run_shell("grep ^\"domain\" /etc/resolv.conf | awk '{$1=\"\"; print $0}'")
        return domain_list

    def get_if_mtu (self, dev):
        ifconfig = self.run_shell("ifconfig %s" % dev)
        m = re.search(r'(?i)mtu[:\s]*(\d+)\b', ifconfig)
        mtu = ''
        if m:
            mtu = m.group(1)
            if mtu == '1500':
                mtu = ''
        return mtu
    #end if_mtu

    def get_intf_ip (self, intf):
        if intf in netifaces.interfaces ():
            ip = netifaces.ifaddresses (intf)[netifaces.AF_INET][0]['addr']
            return ip
        raise RuntimeError, '%s not configured' % intf
    # end 

    def get_device_by_ip (self, ip):
        for i in netifaces.interfaces ():
            try:
                if i == 'pkt1':
                    continue
                if netifaces.ifaddresses (i).has_key (netifaces.AF_INET):
                    if ip == netifaces.ifaddresses (i)[netifaces.AF_INET][0][
                            'addr']:
                        if i == 'vhost0':
                             print "vhost0 is already present!"
    #                        raise RuntimeError, 'vhost0 already running with %s'%ip
                        return i
            except ValueError,e:
                print "Skipping interface %s" % i
        raise RuntimeError, '%s not configured, rerun w/ --physical_interface' % ip
    #end get_device_by_ip
    
    def _is_string_in_file(self, string, filename):
        f_lines=[]
        if os.path.isfile( filename ):
            fd=open(ifcfg_file)
            f_lines=fd.readlines()
            fd.close()
        #end if  
        found= False
        for line in f_lines:
            if string in line:
                found= True
        return found
    #end _is_string_in_file
    
    def _rewrite_ifcfg_file(self, filename, dev, prsv_cfg):
        bond = False
        mac = ''
        temp_dir_name = self._temp_dir_name

        if os.path.isdir ('/sys/class/net/%s/bonding' % dev):
            bond = True
        # end if os.path.isdir...

        mac = netifaces.ifaddresses(dev)[netifaces.AF_LINK][0]['addr']
        ifcfg_file='/etc/sysconfig/network-scripts/ifcfg-%s' %(dev)
        if not os.path.isfile( ifcfg_file ):
            ifcfg_file = temp_dir_name + 'ifcfg-' + dev
            with open (ifcfg_file, 'w') as f:
                f.write ('''#Contrail %s
TYPE=Ethernet
ONBOOT=yes
DEVICE="%s"
USERCTL=yes
NM_CONTROLLED=no
HWADDR=%s
''' % (dev, dev, mac))
                for dcfg in prsv_cfg:
                    f.write(dcfg+'\n')
                f.flush()
        fd=open(ifcfg_file)
        f_lines=fd.readlines()
        fd.close()
        new_f_lines=[]
        remove_items=['IPADDR', 'NETMASK', 'PREFIX', 'GATEWAY', 'HWADDR',
                      'DNS1', 'DNS2', 'BOOTPROTO', 'NM_CONTROLLED', '#Contrail']

        remove_items.append('DEVICE')
        new_f_lines.append('#Contrail %s\n' % dev)
        new_f_lines.append('DEVICE=%s\n' % dev)


        for line in f_lines:
            found=False
            for text in remove_items:
                if text in line:
                    found=True
            if not found:
                new_f_lines.append(line)

        new_f_lines.append('NM_CONTROLLED=no\n')
        if bond:
            new_f_lines.append('SUBCHANNELS=1,2,3\n')
        else:
            new_f_lines.append('HWADDR=%s\n' % mac)

        fdw=open(filename,'w')
        fdw.writelines(new_f_lines)
        fdw.close()

    def migrate_routes(self, device):
        '''
        Sample output of /proc/net/route :
        Iface   Destination     Gateway         Flags   RefCnt  Use     Metric  Mask            MTU     Window  IRTT
        p4p1    00000000        FED8CC0A        0003    0       0       0       00000000        0       0       0
        '''
        with open('/etc/sysconfig/network-scripts/route-vhost0', 'w') as route_cfg_file:
            for route in open('/proc/net/route', 'r').readlines():
                if route.startswith(device):
                    route_fields = route.split()
                    destination = int(route_fields[1], 16)
                    gateway = int(route_fields[2], 16)
                    flags = int(route_fields[3], 16)
                    mask = int(route_fields[7], 16)
                    if flags & 0x2:
                        if destination != 0:
                            route_cfg_file.write(socket.inet_ntoa(struct.pack('I', destination)))
                            route_cfg_file.write('/' + str(bin(mask).count('1')) + ' ')
                            route_cfg_file.write('via ')
                            route_cfg_file.write(socket.inet_ntoa(struct.pack('I', gateway)) + ' ')
                            route_cfg_file.write('dev vhost0')
                        #end if detination...
                    #end if flags &...
                #end if route.startswith...
            #end for route...
        #end with open...
    #end def migrate_routes

    def _replace_discovery_server(self, agent_elem, discovery_ip, ncontrols):
        for srv in agent_elem.findall('discovery-server'):
            agent_elem.remove(srv)

        pri_dss_elem = ET.Element('discovery-server')
        pri_dss_ip = ET.SubElement(pri_dss_elem, 'ip-address')
        pri_dss_ip.text = '%s' %(discovery_ip)

        xs_instances = ET.SubElement(pri_dss_elem, 'control-instances')
        xs_instances.text = '%s' %(ncontrols)
        agent_elem.append(pri_dss_elem)

    #end _replace_discovery_server


    def fixup_config_files(self):
        temp_dir_name = self._temp_dir_name
        hostname = socket.gethostname()
        cfgm_ip = self._args.cfgm_ip
        collector_ip = self._args.collector_ip
        use_certs = True if self._args.use_certs else False

        whoami = getpass.getuser()
        self.run_shell("sudo mkdir -p /etc/contrail")
        self.run_shell("sudo chown %s /etc/contrail" % whoami)
        self.run_shell("sudo mkdir -p /etc/quantum/plugins/contrail")
        self.run_shell("sudo chown %s /etc/quantum/plugins/contrail" % whoami)
        # generate service token
        self.service_token = self._args.service_token
        if not self.service_token:
            self.run_shell("sudo openssl rand -hex 10 > /etc/contrail/service.token")
            tok_fd = open('/etc/contrail/service.token')
            self.service_token = tok_fd.read()
            tok_fd.close()
            # local("sudo chmod 400 /etc/contrail/service.token")

        """ dsetia
        # TODO till post of openstack-horizon.spec is fixed...
        if 'config' in self._args.role:
            pylibpath = local ('/usr/bin/python -c "from distutils.sysconfig import get_python_lib; print get_python_lib()"', capture = True)
            local('runuser -p apache -c "echo yes | django-admin collectstatic --settings=settings --pythonpath=%s/openstack_dashboard"' % pylibpath)
        """

        # Disable selinux
        self.run_shell("sudo sed 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config > config.new")
        self.run_shell("sudo mv config.new /etc/selinux/config")
        self.run_shell("setenforce 0")

        # Disable iptables
        self.run_shell("sudo chkconfig iptables off")
        self.run_shell("sudo iptables --flush")

        if 'config' in self._args.role or 'compute' in self._args.role or 'openstack' in self._args.role:
            openstack_ip = self._args.openstack_ip
            compute_ip = self._args.compute_ip
            cfgm_ip = self._args.cfgm_ip
            temp_dir_name = "/tmp"

            self.run_shell("echo 'SERVICE_TOKEN=%s' >> %s/ctrl-details" 
                                            %(self.service_token, temp_dir_name))
            self.run_shell("echo 'ADMIN_TOKEN=%s' >> %s/ctrl-details" %(ks_admin_password, temp_dir_name))
            self.run_shell("echo 'CONTROLLER=%s' >> %s/ctrl-details" %(openstack_ip, temp_dir_name))
            self.run_shell("echo 'QUANTUM=%s' >> %s/ctrl-details" %(cfgm_ip, temp_dir_name))
            self.run_shell("echo 'COMPUTE=%s' >> %s/ctrl-details" %(compute_ip, temp_dir_name))
            if 'compute' in self._args.role:
                self.run_shell("echo 'CONTROLLER_MGMT=%s' >> %s/ctrl-details" %(self._args.openstack_mgmt_ip, temp_dir_name))
            self.run_shell("sudo cp %s/ctrl-details /etc/contrail/ctrl-details" %(temp_dir_name))
            self.run_shell("rm %s/ctrl-details" %(temp_dir_name))

        # database (cassandra setup in contrail.sh)

        # collector in Phase 2
                    
        if 'config' in self._args.role:
            openstack_ip = self._args.openstack_ip
            cassandra_server_list = [(cassandra_server_ip, '9160') for cassandra_server_ip in self._args.cassandra_ip_list]
            template_vals = {'__contrail_ifmap_server_ip__': cfgm_ip,
                             '__contrail_ifmap_server_port__': '8444' if use_certs else '8443',
                             '__contrail_ifmap_username__': 'api-server',
                             '__contrail_ifmap_password__': 'api-server',
                             '__contrail_listen_ip_addr__': '0.0.0.0',
                             '__contrail_listen_port__': '8082',
                             '__contrail_use_certs__': use_certs,
                             '__contrail_keyfile_location__': '/etc/contrail/ssl/private_keys/apiserver_key.pem',
                             '__contrail_certfile_location__': '/etc/contrail/ssl/certs/apiserver.pem',
                             '__contrail_cacertfile_location__': '/etc/contrail/ssl/certs/ca.pem',
                             '__contrail_multi_tenancy__': self._args.multi_tenancy,
                             '__contrail_openstack_ip__': openstack_ip,
                             '__contrail_admin_user__': ks_admin_user,
                             '__contrail_admin_password__': ks_admin_password,
                             '__contrail_admin_tenant_name__': ks_admin_tenant_name,
                             '__contrail_memcached_opt__': 'memcache_servers=127.0.0.1:11211' if self._args.multi_tenancy else '',
                             '__contrail_log_file__': '/var/log/contrail/api.log',
                             '__contrail_cassandra_server_list__' : ' '.join('%s:%s' % cassandra_server for cassandra_server in cassandra_server_list),
                             '__contrail_disc_server_ip__': self._args.discovery_ip or '',
                             '__contrail_disc_server_port__': '5998',
                            }
            self._template_substitute_write(api_server_conf_template,
                                            template_vals, temp_dir_name + '/api_server.conf')
            self.run_shell("sudo mv %s/api_server.conf /etc/contrail/" %(temp_dir_name))

            template_vals = {'__contrail_api_server_ip__': cfgm_ip,
                             '__contrail_api_server_port__': '8082',
                             '__contrail_multi_tenancy__': self._args.multi_tenancy,
                             '__contrail_keystone_ip__': '127.0.0.1',
                             '__contrail_admin_token__': ks_admin_password,
                             '__contrail_admin_user__': ks_admin_user,
                             '__contrail_admin_password__': ks_admin_password,
                             '__contrail_admin_tenant_name__': ks_admin_tenant_name,
                        }
            self._template_substitute_write(quantum_conf_template,
                                            template_vals, temp_dir_name + '/contrail_plugin.ini')

            self.run_shell("sudo mv %s/contrail_plugin.ini /etc/quantum/plugins/contrail/contrail_plugin.ini" %(temp_dir_name))

            template_vals = {'__contrail_ifmap_server_ip__': cfgm_ip,
                             '__contrail_ifmap_server_port__': '8444' if use_certs else '8443',
                             '__contrail_ifmap_username__': 'schema-transformer',
                             '__contrail_ifmap_password__': 'schema-transformer',
                             '__contrail_api_server_ip__': cfgm_ip,
                             '__contrail_api_server_port__': '8082',
                             '__contrail_zookeeper_server_ip__': '127.0.0.1',
                             '__contrail_zookeeper_server_port__': '2181',
                             '__contrail_use_certs__': use_certs,
                             '__contrail_keyfile_location__': '/etc/contrail/ssl/private_keys/schema_xfer_key.pem',
                             '__contrail_certfile_location__': '/etc/contrail/ssl/certs/schema_xfer.pem',
                             '__contrail_cacertfile_location__': '/etc/contrail/ssl/certs/ca.pem',
                             '__contrail_admin_user__': ks_admin_user,
                             '__contrail_admin_password__': ks_admin_password,
                             '__contrail_admin_tenant_name__': ks_admin_tenant_name,
                             '__contrail_log_file__' : '/var/log/contrail/schema.log',
                             '__contrail_cassandra_server_list__' : ' '.join('%s:%s' % cassandra_server for cassandra_server in cassandra_server_list),
                             '__contrail_disc_server_ip__': self._args.discovery_ip or '',
                             '__contrail_disc_server_port__': '5998',
                            }
            self._template_substitute_write(schema_transformer_conf_template,
                                            template_vals, temp_dir_name + '/schema_transformer.conf')
            self.run_shell("sudo mv %s/schema_transformer.conf /etc/contrail/schema_transformer.conf" %(temp_dir_name))

            template_vals = {'__contrail_ifmap_server_ip__': cfgm_ip,
                             '__contrail_ifmap_server_port__': '8444' if use_certs else '8443',
                             '__contrail_ifmap_username__': 'svc-monitor',
                             '__contrail_ifmap_password__': 'svc-monitor',
                             '__contrail_api_server_ip__': cfgm_ip,
                             '__contrail_api_server_port__': '8082',
                             '__contrail_openstack_ip__': openstack_ip,
                             '__contrail_zookeeper_server_ip__': '127.0.0.1',
                             '__contrail_zookeeper_server_port__': '2181',
                             '__contrail_use_certs__': use_certs,
                             '__contrail_keyfile_location__': '/etc/contrail/ssl/private_keys/svc_monitor_key.pem',
                             '__contrail_certfile_location__': '/etc/contrail/ssl/certs/svc_monitor.pem',
                             '__contrail_cacertfile_location__': '/etc/contrail/ssl/certs/ca.pem',
                             '__contrail_admin_user__': ks_admin_user,
                             '__contrail_admin_password__': ks_admin_password,
                             '__contrail_admin_tenant_name__': ks_admin_tenant_name,
                             '__contrail_log_file__' : '/var/log/contrail/svc-monitor.log',
                             '__contrail_cassandra_server_list__' : ' '.join('%s:%s' % cassandra_server for cassandra_server in cassandra_server_list),
                             '__contrail_disc_server_ip__': self._args.discovery_ip or '',
                             '__contrail_disc_server_port__': '5998',
                            }
            self._template_substitute_write(svc_monitor_conf_template,
                                            template_vals, temp_dir_name + '/svc_monitor.conf')
            self.run_shell("sudo mv %s/svc_monitor.conf /etc/contrail/svc_monitor.conf" %(temp_dir_name))

            template_vals = {
                             '__contrail_zk_server_ip__': '127.0.0.1',
                             '__contrail_zk_server_port__': '2181',
                             '__contrail_listen_ip_addr__': cfgm_ip,
                             '__contrail_listen_port__': '5998',
                             '__contrail_log_local__': 'True',
                             '__contrail_log_file__': '/var/log/contrail/discovery.log',
                            }
            self._template_substitute_write(discovery_conf_template,
                                            template_vals, temp_dir_name + '/discovery.conf')
            self.run_shell("sudo mv %s/discovery.conf /etc/contrail/" %(temp_dir_name))

            template_vals = {
                             '__contrail_openstack_ip__': openstack_ip,
                            }
            self._template_substitute_write(vnc_api_lib_ini_template,
                                            template_vals, temp_dir_name + '/vnc_api_lib.ini')
            self.run_shell("sudo mv %s/vnc_api_lib.ini /etc/contrail/" %(temp_dir_name))

            template_vals = {
                             '__api_server_ip__'  : cfgm_ip,
                             '__api_server_port__': '8082',
                             '__multitenancy__'   : 'False',
                             '__contrail_admin_user__': ks_admin_user,
                             '__contrail_admin_password__': ks_admin_password,
                             '__contrail_admin_tenant_name__': ks_admin_tenant_name,
                            }
            self._template_substitute_write(contrail_plugin_template,
                                            template_vals, temp_dir_name + '/ContrailPlugin.ini')
            self.run_shell("sudo cp %s/ContrailPlugin.ini /opt/stack/neutron/etc/neutron/plugins/juniper/contrail/" %(temp_dir_name))
            self.run_shell("sudo mv %s/ContrailPlugin.ini /etc/contrail/" %(temp_dir_name))

        if 'control' in self._args.role:
            control_ip = self._args.control_ip
            certdir = '/var/lib/puppet/ssl' if self._args.puppet_server else '/etc/contrail/ssl'
            template_vals = {'__contrail_ifmap_srv_ip__': cfgm_ip,
                             '__contrail_ifmap_srv_port__': '8444' if use_certs else '8443',
                             '__contrail_ifmap_usr__': '%s' %(control_ip),
                             '__contrail_ifmap_paswd__': '%s' %(control_ip),
                             '__contrail_collector__': collector_ip,
                             '__contrail_collector_port__': '8086',
                             '__contrail_discovery_ip__': self._args.discovery_ip,
                             '__contrail_hostname__': hostname,
                             '__contrail_host_ip__': control_ip,
                             '__contrail_bgp_port__': '179',
                             '__contrail_cert_ops__': '"--use-certs=%s"' %(certdir) if use_certs else '',
                             '__contrail_log_local__': '',
                             '__contrail_logfile__': '--log-file=/var/log/contrail/control.log',
                            }
            self._template_substitute_write(bgp_param_template,
                                            template_vals, temp_dir_name + '/control_param')
            self.run_shell("sudo mv %s/control_param /etc/contrail/control_param" %(temp_dir_name))

            dns_template_vals = {'__contrail_ifmap_srv_ip__': cfgm_ip,
                             '__contrail_ifmap_srv_port__': '8444' if use_certs else '8443',
                             '__contrail_ifmap_usr__': '%s.dns' %(control_ip),
                             '__contrail_ifmap_paswd__': '%s.dns' %(control_ip),
                             '__contrail_collector__': collector_ip,
                             '__contrail_collector_port__': '8086',
                             '__contrail_discovery_ip__': self._args.discovery_ip,
                             '__contrail_host_ip__': control_ip,
                             '__contrail_cert_ops__': '"--use-certs=%s"' %(certdir) if use_certs else '',
                             '__contrail_log_local__': '',
                             '__contrail_logfile__': '--log-file=/var/log/contrail/dns.log',
                            }
            self._template_substitute_write(dns_param_template,
                                            dns_template_vals, temp_dir_name + '/dns_param')
            self.run_shell("sudo mv %s/dns_param /etc/contrail/dns_param" %(temp_dir_name))

            dir = "/opt/stack/contrail/third_party/irond-0.3.0-bin"
            self.run_shell("echo >> %s/basicauthusers.properties" % dir)
            self.run_shell("echo '# Contrail users' >> %s/basicauthusers.properties" % dir)
            self.run_shell("echo 'api-server:api-server' >> %s/basicauthusers.properties" % dir)
            self.run_shell("echo 'schema-transformer:schema-transformer' >> %s/basicauthusers.properties" % dir)
            self.run_shell("sudo sed -e '/%s:/d' -e '/%s.dns:/d' %s/%s > %s/%s.new" \
                          %(control_ip, control_ip, dir, 'basicauthusers.properties',
                                                    dir, 'basicauthusers.properties'))
            self.run_shell("echo '%s:%s' >> %s/%s.new" \
                     %(control_ip, control_ip, dir, 'basicauthusers.properties'))
            self.run_shell("echo '%s.dns:%s.dns' >> %s/%s.new" \
                     %(control_ip, control_ip, dir, 'basicauthusers.properties'))
            self.run_shell("sudo mv %s/%s.new %s/%s" \
                % (dir, 'basicauthusers.properties', dir, 'basicauthusers.properties'))
            self.run_shell("echo '%s=%s--0000000001-1' >> %s/%s" \
                     %(control_ip, control_ip, dir, 'publisher.properties'))
            if self._args.puppet_server:
                self.run_shell("echo '    server = %s' >> /etc/puppet/puppet.conf" \
                    %(self._args.puppet_server))

        if 'compute' in self._args.role:
            dist = platform.dist()[0]
            # add /dev/net/tun in cgroup_device_acl needed for type=ethernet interfaces
            ret = self.call_cmd("sudo grep -q '^cgroup_device_acl' /etc/libvirt/qemu.conf")
            if ret == 1:
                self.run_shell('sudo cp /etc/libvirt/qemu.conf qemu.conf')
                self.run_shell('sudo chown %s qemu.conf' % whoami)
                if  dist == 'centos':
                    self.run_shell('sudo echo "clear_emulator_capabilities = 1" >> qemu.conf')
                    self.run_shell('sudo echo \'user = "root"\' >> qemu.conf')
                    self.run_shell('sudo echo \'group = "root"\' >> qemu.conf')
                self.run_shell('sudo echo \'cgroup_device_acl = [\' >> qemu.conf')
                self.run_shell('sudo echo \'    "/dev/null", "/dev/full", "/dev/zero",\' >> qemu.conf')
                self.run_shell('sudo echo \'    "/dev/random", "/dev/urandom",\' >> qemu.conf')
                self.run_shell('sudo echo \'    "/dev/ptmx", "/dev/kvm", "/dev/kqemu",\' >> qemu.conf')
                self.run_shell('sudo echo \'    "/dev/rtc", "/dev/hpet","/dev/net/tun",\' >> qemu.conf')
                self.run_shell('sudo echo \']\' >> qemu.conf')
                self.run_shell('sudo cp qemu.conf /etc/libvirt/qemu.conf')
                self._fixed_qemu_conf = True
                # add "alias bridge off" in /etc/modprobe.conf for Centos
            if  dist == 'centos':
                self.run_shell('sudo echo "alias bridge off" > /etc/modprobe.conf')

        if 'compute' in self._args.role :
            openstack_ip = self._args.openstack_ip
            compute_ip = self._args.compute_ip
            discovery_ip = self._args.discovery_ip
            ncontrols = self._args.ncontrols
            physical_interface = self._args.physical_interface
            non_mgmt_ip = self._args.non_mgmt_ip 
            non_mgmt_gw = self._args.non_mgmt_gw
            vhost_ip = compute_ip
            multi_net= False
            if non_mgmt_ip :
                if non_mgmt_ip != compute_ip:
                    multi_net= True
                    vhost_ip= non_mgmt_ip

            dev = None
            compute_dev = None
            if physical_interface:
                if physical_interface in netifaces.interfaces ():
                    dev = physical_interface
                else:
                     raise KeyError, 'Interface %s in present' % (
                             physical_interface)
            else:
                # deduce the phy interface from ip, if configured
                dev = self.get_device_by_ip (vhost_ip)
                if multi_net:
                    compute_dev = self.get_device_by_ip (compute_ip)

            mac = None
            if dev and dev != 'vhost0' :
                mac = netifaces.ifaddresses (dev)[netifaces.AF_LINK][0][
                            'addr']
                if mac:
                    with open ('%s/default_pmac' % temp_dir_name, 'w') as f:
                        f.write (mac)
                    self.run_shell("sudo mv %s/default_pmac /etc/contrail/default_pmac" % (temp_dir_name))
                else:
                    raise KeyError, 'Interface %s Mac %s' % (str (dev), str (mac))
                netmask = netifaces.ifaddresses (dev)[netifaces.AF_INET][0][
                                'netmask']
                if multi_net:
                    gateway= non_mgmt_gw
                else:
                    gateway = self.find_gateway (dev)
                cidr = str (netaddr.IPNetwork('%s/%s' % (vhost_ip, netmask)))

                template_vals = {
                    '__contrail_dev__' : 'dev=%s' % dev,
                    '__contrail_collector__' : collector_ip
                }
                self._template_substitute_write(agent_param_template,
                    template_vals, "agent_param")
                self.run_shell("sudo mv agent_param /etc/contrail/agent_param")

                template_vals = {
                    '__contrail_box_ip__' : cidr,
                    '__contrail_gateway__' : gateway,
                    '__contrail_intf__' : dev,
                    '__contrail_disc_ip__' : discovery_ip,
                    '__contrail_instances__' : ncontrols,
                    '__contrail_control_ip__' : cfgm_ip,
                }
                self._template_substitute_write(agent_conf_template,
                    template_vals, "agent.conf")
                self.run_shell("sudo mv agent.conf /etc/contrail/agent.conf")

                ## make ifcfg-vhost0
                with open ('%s/ifcfg-vhost0' % temp_dir_name, 'w') as f:
                    f.write ('''#Contrail vhost0
DEVICE=vhost0
ONBOOT=yes
BOOTPROTO=none
IPV6INIT=no
USERCTL=yes
IPADDR=%s
NETMASK=%s
NM_CONTROLLED=no
#NETWORK MANAGER BUG WORKAROUND
SUBCHANNELS=1,2,3
''' % (vhost_ip, netmask ))
                    # Don't set gateway and DNS on vhost0 if on non-mgmt network
                    if not multi_net:
                        if gateway:
                           f.write('GATEWAY=%s\n' %( gateway ) )
                        dns_list = self.get_dns_servers(dev)
                        for i, dns in enumerate(dns_list):
                            f.write('DNS%d=%s\n' % (i+1, dns))
                        domain_list = self.get_domain_search_list()
                        if domain_list:
                            f.write('DOMAIN="%s"\n'% domain_list)

                    prsv_cfg = []
                    mtu = self.get_if_mtu (dev)
                    if mtu:
                        dcfg = 'MTU=%s' % str(mtu)
                        f.write(dcfg+'\n')
                        prsv_cfg.append (dcfg)
                    f.flush ()
#            if dev != 'vhost0':
                    self.run_shell("sudo mv %s/ifcfg-vhost0 /etc/sysconfig/network-scripts/ifcfg-vhost0" % (temp_dir_name))
                    ## make ifcfg-$dev
                    if not os.path.isfile (
                            '/etc/sysconfig/network-scripts/ifcfg-%s.rpmsave' % dev):
                        self.run_shell("sudo cp /etc/sysconfig/network-scripts/ifcfg-%s /etc/sysconfig/network-scripts/ifcfg-%s.rpmsave" % (dev, dev))
                    self._rewrite_ifcfg_file('%s/ifcfg-%s' % (temp_dir_name, dev), dev, prsv_cfg)

                    if multi_net :
                        self.migrate_routes(dev)

                    self.run_shell("sudo mv %s/ifcfg-%s /etc/contrail/" % (temp_dir_name, dev))

                    self.run_shell("sudo chkconfig network on")
            #end if dev and dev != 'vhost0' :

        # role == compute && !cfgm

        if 'webui' in self._args.role:
            openstack_ip = self._args.openstack_ip
            self.run_shell("sudo sed \"s/config.cnfg.server_ip.*/config.cnfg.server_ip = '%s';/g\" /etc/contrail/config.global.js > config.global.js.new" %(cfgm_ip))
            self.run_shell("sudo mv config.global.js.new /etc/contrail/config.global.js")
            self.run_shell("sudo sed \"s/config.networkManager.ip.*/config.networkManager.ip = '%s';/g\" /etc/contrail/config.global.js > config.global.js.new" %(cfgm_ip))
            self.run_shell("sudo mv config.global.js.new /etc/contrail/config.global.js")
            self.run_shell("sudo sed \"s/config.imageManager.ip.*/config.imageManager.ip = '%s';/g\" /etc/contrail/config.global.js > config.global.js.new" %(openstack_ip))
            self.run_shell("sudo mv config.global.js.new /etc/contrail/config.global.js")
            self.run_shell("sudo sed \"s/config.computeManager.ip.*/config.computeManager.ip = '%s';/g\" /etc/contrail/config.global.js > config.global.js.new" %(openstack_ip))
            self.run_shell("sudo mv config.global.js.new /etc/contrail/config.global.js")
            self.run_shell("sudo sed \"s/config.identityManager.ip.*/config.identityManager.ip = '%s';/g\" /etc/contrail/config.global.js > config.global.js.new" %(openstack_ip))
            self.run_shell("sudo mv config.global.js.new /etc/contrail/config.global.js")
            self.run_shell("sudo sed \"s/config.storageManager.ip.*/config.storageManager.ip = '%s';/g\" /etc/contrail/config.global.js > config.global.js.new" %(openstack_ip))
            self.run_shell("sudo mv config.global.js.new /etc/contrail/config.global.js")            
            if collector_ip:
                self.run_shell("sudo sed \"s/config.analytics.server_ip.*/config.analytics.server_ip = '%s';/g\" /etc/contrail/config.global.js > config.global.js.new" %(collector_ip))
                self.run_shell("sudo mv config.global.js.new /etc/contrail/config.global.js")
            if self._args.cassandra_ip_list:
                self.run_shell("sudo sed \"s/config.cassandra.server_ips.*/config.cassandra.server_ips = %s;/g\" /etc/contrail/config.global.js > config.global.js.new" %(str(self._args.cassandra_ip_list)))
                self.run_shell("sudo mv config.global.js.new /etc/contrail/config.global.js")    

        """
        if 'config' in self._args.role and self._args.use_certs:
            local("sudo ./contrail_setup_utils/setup-pki.sh /etc/contrail/ssl")
        """

    #end fixup_config_files

    def add_vnc_config(self):
        if 'compute' in self._args.role:
            cfgm_ip = self._args.cfgm_ip
            compute_ip = self._args.compute_ip
            compute_hostname = socket.gethostname()
            with settings(host_string = 'root@%s' %(cfgm_ip), password = env.password):
                prov_args = "--host_name %s --host_ip %s --api_server_ip %s --oper add " \
                            "--admin_user %s --admin_password %s --admin_tenant_name %s" \
                            %(compute_hostname, compute_ip, cfgm_ip, ks_admin_user, ks_admin_password, ks_admin_tenant_name)
                run("source /opt/contrail/api-venv/bin/activate && python /opt/contrail/utils/provision_vrouter.py %s" %(prov_args))
    #end add_vnc_config

    def cleanup(self):
        os.removedirs(self._temp_dir_name)
    #end cleanup

    def do_setup(self):
        # local configuration
        self.fixup_config_files()

        # global vnc configuration
        # self.add_vnc_config() dsetia disabled temporarily

        self.cleanup()
    #end do_setup

#end class Setup

def main(args_str = None):
    setup_obj = Setup(args_str)
    setup_obj.do_setup()
#end main

if __name__ == "__main__":
    main()
