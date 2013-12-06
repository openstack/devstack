#! /usr/bin/env python
"""
net_policy_join.py [options] net1_uuid net2_uuid

Calls Contrail API server to create a network policy to allow all
traffic between net1 and net2

"""

# See contrail/build/debug/config/api-server/doc/build/html/tutorial_with_library.html

import argparse
import os
from vnc_api import vnc_api


arg_defaults = {}

# options from environment
for env_name, opt_name in (
    ('OS_TENANT_NAME', 'auth_tenant'), # demo
    ('OS_USERNAME', 'auth_user'),
    ('OS_PASSWORD', 'auth_password'),
    ('OS_AUTH_URL', 'auth_url'), # 'http://192.168.56.119:5000/v2.0'
    ('OS_IDENTITY_API_VERSION', 'auth_version')
    ):
    if env_name in os.environ:
        arg_defaults[opt_name] = os.environ[env_name]

# options from argv
parser = argparse.ArgumentParser(
    description=__doc__,
    formatter_class=argparse.RawDescriptionHelpFormatter,
)
parser.add_argument(
    "--auth_url", default='http://127.0.0.1:5000/v2.0',
    help="IP address of keystone server")
parser.add_argument(
    "--auth_tenant", default='demo',
    help="Tenant name for keystone admin user")
parser.add_argument(
    "--auth_version", default='2.0',
    help="Version of keystone server")
parser.add_argument(
    "--auth_user", default='admin',
    help="Name of keystone admin user")
parser.add_argument(
    "--auth_password", default='contrail123',
    help="Password of keystone admin user")
parser.add_argument(
    "--api_host", default='127.0.0.1',
    help="Hostnmae of api server")
parser.add_argument(
    "--api_port", default=8082,
    help="Port of api server")
parser.add_argument("net1_uuid", help="UUIDs of subnets to join")
parser.add_argument("net2_uuid")
parser.set_defaults(**arg_defaults)
args = parser.parse_args()
    
vnc_lib = vnc_api.VncApi(api_server_host=args.api_host,
                         api_server_port=args.api_port,
                         )

net1 = vnc_lib.virtual_network_read(id = args.net1_uuid)
net2 = vnc_lib.virtual_network_read(id = args.net2_uuid)

pol1 = vnc_api.NetworkPolicy(
    'policy-%s-%s-any' % (net1.get_fq_name_str(), net2.get_fq_name_str()),
    network_policy_entries = vnc_api.PolicyEntriesType(
        [vnc_api.PolicyRuleType(
            direction = '<>',
            action_list = vnc_api.ActionListType(simple_action='pass'),
            protocol = 'any',
            src_addresses = [
                vnc_api.AddressType(virtual_network = net1.get_fq_name_str())
            ],
            src_ports = [vnc_api.PortType(-1, -1)],
            dst_addresses = [
                vnc_api.AddressType(virtual_network = net2.get_fq_name_str())
            ],
            dst_ports = [vnc_api.PortType(-1, -1)])
         ]))
vnc_lib.network_policy_create(pol1)

net1.add_network_policy(pol1, vnc_api.VirtualNetworkPolicyType(
    sequence = vnc_api.SequenceType(0, 0)))
vnc_lib.virtual_network_update(net1)

net2.add_network_policy(pol1, vnc_api.VirtualNetworkPolicyType(
    sequence = vnc_api.SequenceType(0, 0)))
vnc_lib.virtual_network_update(net2)

