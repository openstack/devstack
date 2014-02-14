#!/usr/bin/python 
"""
Common utility functions for Contrail scripts

adapted from from contrail_lib.py in https://github.com/Juniper/vrouter-xen-utils

Noel Burton-Krahn <noel@pistoncloud.com>
"""

import sys

import thrift
import uuid
import shlex

import instance_service
from thrift.protocol import TBinaryProtocol
from thrift.transport import TTransport
from nova.utils import execute
from nova.openstack.common.processutils import ProcessExecutionError

def format_dict(dict, style='table'):
    """stringify dict as json, shell, table (ascii), or python"""
    if style == 'json':
        import json
        return json.dumps(dict)

    elif style == 'table':
        from prettytable import PrettyTable
        s = PrettyTable(["Field", "Value"])
        s.align = 'l'
        for (k,v) in sorted(dict.items()):
            s.add_row([k, v])
        return str(s)

    elif style == 'shell':
        from StringIO import StringIO
        import pipes
        
        s = StringIO()
        for (k,v) in sorted(dict.items()):
            s.write("%s=%s\n" % (k, pipes.quote(v)))
        return s.getvalue()
    
    elif style == 'python':
        import pprint
        pprint.pprint(dict)

    else:
        raise ValueError("unknown format: %s.  Expected table, shell, json, or python")

def sudo(str, args=None, **opts):
    """shortcut to nova.utils.execute.
    Breaks str into array using shlex and allows %-substitutions for args
    """
    
    # run as root by default
    if 'run_as_root' not in opts:
        opts['run_as_root']=True
    i=0
    l = []
    for s in shlex.split(str):
        if s[0] in "%\\":
            s = s % (args[i],)
            i += 1
        l.append(s)
    execute(*l, **opts)

def vrouter_rpc():
    """Return an RPC client connection to the local vrouter service"""
    import thrift.transport.TSocket as TSocket
    socket = TSocket.TSocket('127.0.0.1', 9090)
    transport = TTransport.TFramedTransport(socket)
    transport.open()
    protocol = TBinaryProtocol.TBinaryProtocol(transport)
    import instance_service.InstanceService as InstanceService
    return InstanceService.Client(protocol)

def uuid_array_to_str(array):
    """convert an array of integers into a UUID string"""
    hexstr = ''.join([ '%02x' % x for x in array ])
    return str(uuid.UUID(hexstr))

def uuid_from_string(idstr):
    """Convert an uuid into an array of integers"""
    if not idstr:
        return None
    hexstr = uuid.UUID(idstr).hex
    return [int(hexstr[i:i+2], 16) for i in range(32) if i % 2 == 0]

class AllocationError(Exception):
    pass

def link_exists_func(*netns_list):
    """returns a function(name) that returns True if name is used in any namespace in netns_list

    Example:

      link_exists = link_exists_func('', 'mynamespace')
      unique_name = new_interface_name(exists_func=link_exists)
    """

    # default: test only the default netns
    if not netns_list:
        netns_list = ['']

    # create a function that tests all netns_list
    def link_exists(veth):
        for netns in netns_list:
            try:
                cmd = ''
                args = []
                if netns:
                    cmd = 'ip netns exec %s '
                    args = [netns]
                sudo(cmd + 'ip link show %s', args + [veth])
                return True
            except ProcessExecutionError:
                pass
    return link_exists


def new_interface_name(suffix='', prefix='tap', maxlen=15, max_retries=100, exists_func=None):
    """return a new unique name for a network interface.

    Raises AllocationError if it can't find a unique name in max_tries
    """
    import re
    import random

    # default: look only in the default namespace
    if not exists_func:
        exists_func = link_exists_func()
        
    suflen = maxlen - len(prefix)
    sufmax = int('f' * suflen, 16)
    def rand_suf():
        return ('%x' % random.randint(1, sufmax)).zfill(suflen)

    # try the user-supplied suffix to start, but fall back to  
    suffix = suffix[-suflen:]
    if len(suffix) == 0:
        suffix = rand_suf()

    retry = 0
    tap_dev_name = prefix + suffix
    while exists_func(tap_dev_name):
        if retry >= max_retries:
            raise AllocationError("Couldn't find a unique tap name after %d retries.  Last tried %s." % (retry, tap_dev_name))
        retry += 1
        tap_dev_name = prefix + rand_suf()
    return tap_dev_name
