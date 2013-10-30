#!/usr/bin/python
#
# Copyright (c) 2013 Juniper Networks, Inc. All rights reserved.
#

import sys
import argparse
import ConfigParser

from vnc_api.vnc_api import *


class VrouterProvisioner(object):

    def __init__(self, args_str=None):
        self._args = None
        if not args_str:
            args_str = ' '.join(sys.argv[1:])
        self._parse_args(args_str)

        self._vnc_lib = VncApi(
            self._args.admin_user, self._args.admin_password,
            self._args.admin_tenant_name,
            self._args.api_server_ip,
            self._args.api_server_port, '/')
        gsc_obj = self._vnc_lib.global_system_config_read(
            fq_name=['default-global-system-config'])
        self._global_system_config_obj = gsc_obj

        rt_inst_obj = self._vnc_lib.routing_instance_read(
            fq_name=['default-domain', 'default-project',
                     'ip-fabric', '__default__'])
        self._fab_rt_inst_obj = rt_inst_obj

        if self._args.oper == 'add':
            self.add_vrouter()
        elif self._args.oper == 'del':
            self.del_vrouter()
        else:
            print "Unknown operation %s. Only 'add' and 'del' supported"\
                % (self._args.oper)

    # end __init__

    def _parse_args(self, args_str):
        '''
        Eg. python provision_vrouter.py --host_name a3s30.contrail.juniper.net
                                        --host_ip 10.1.1.1
                                        --api_server_ip 127.0.0.1
                                        --api_server_port 8082
                                        --oper <add | del>
        '''

        # Source any specified config/ini file
        # Turn off help, so we print all options in response to -h
        conf_parser = argparse.ArgumentParser(add_help=False)

        conf_parser.add_argument("-c", "--conf_file",
                                 help="Specify config file", metavar="FILE")
        args, remaining_argv = conf_parser.parse_known_args(args_str.split())

        defaults = {
            'api_server_ip': '127.0.0.1',
            'api_server_port': '8082',
            'oper': 'add',
            'control_names': [],
        }
        ksopts = {
            'admin_user': 'user1',
            'admin_password': 'password1',
            'admin_tenant_name': 'default-domain'
        }

        if args.conf_file:
            config = ConfigParser.SafeConfigParser()
            config.read([args.conf_file])
            defaults.update(dict(config.items("DEFAULTS")))
            if 'KEYSTONE' in config.sections():
                ksopts.update(dict(config.items("KEYSTONE")))

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
        defaults.update(ksopts)
        parser.set_defaults(**defaults)

        parser.add_argument(
            "--host_name", help="hostname name of compute-node")
        parser.add_argument("--host_ip", help="IP address of compute-node")
        parser.add_argument(
            "--control_names",
            help="List of control-node names compute node connects to")
        parser.add_argument(
            "--api_server_ip", help="IP address of api server")
        parser.add_argument("--api_server_port", help="Port of api server")
        parser.add_argument(
            "--oper", default='add',
            help="Provision operation to be done(add or del)")
        parser.add_argument(
            "--admin_user", help="Name of keystone admin user")
        parser.add_argument(
            "--admin_password", help="Password of keystone admin user")
        parser.add_argument(
            "--admin_tenant_name", help="Tenamt name for keystone admin user")

        self._args = parser.parse_args(remaining_argv)

    # end _parse_args

    def add_vrouter(self):
        gsc_obj = self._global_system_config_obj

        vrouter_obj = VirtualRouter(
            self._args.host_name, gsc_obj,
            virtual_router_ip_address=self._args.host_ip)
        vrouter_exists = True
        try:
            vrouter_obj = self._vnc_lib.virtual_router_read(
                fq_name=vrouter_obj.get_fq_name())
            vrouter_obj.set_bgp_router_list([])
        except NoIdError:
            vrouter_exists = False

        for bgp in self._args.control_names:
            bgp_router_fq_name = copy.deepcopy(
                self._fab_rt_inst_obj.get_fq_name())
            bgp_router_fq_name.append(bgp)
            bgp_router_obj = vnc_lib.bgp_router_read(
                fq_name=bgp_router_fq_name)
            vrouter_obj.add_bgp_router(bgp_router_obj)

        if vrouter_exists:
            self._vnc_lib.virtual_router_update(vrouter_obj)
        else:
            self._vnc_lib.virtual_router_create(vrouter_obj)

    # end add_vrouter

    def del_vrouter(self):
        gsc_obj = self._global_system_config_obj
        vrouter_obj = VirtualRouter(self._args.host_name, gsc_obj)
        self._vnc_lib.virtual_router_delete(
            fq_name=vrouter_obj.get_fq_name())
    # end del_vrouter

# end class VrouterProvisioner


def main(args_str=None):
    VrouterProvisioner(args_str)
# end main

if __name__ == "__main__":
    main()
