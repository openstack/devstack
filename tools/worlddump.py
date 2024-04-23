#!/usr/bin/env python3
#
# Copyright 2014 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.


"""Dump the state of the world for post mortem."""

import argparse
import datetime
import fnmatch
import io
import os
import shutil
import subprocess
import sys


GMR_PROCESSES = (
    'nova-compute',
    'neutron-dhcp-agent',
    'neutron-l3-agent',
    'neutron-linuxbridge-agent',
    'neutron-metadata-agent',
    'neutron-openvswitch-agent',
    'cinder-volume',
)


def get_options():
    parser = argparse.ArgumentParser(
        description='Dump world state for debugging')
    parser.add_argument('-d', '--dir',
                        default='.',
                        help='Output directory for worlddump')
    parser.add_argument('-n', '--name',
                        default='',
                        help='Additional name to tag into file')
    return parser.parse_args()


def filename(dirname, name=""):
    now = datetime.datetime.now(datetime.timezone.utc)
    fmt = "worlddump-%Y-%m-%d-%H%M%S"
    if name:
        fmt += "-" + name
    fmt += ".txt"
    return os.path.join(dirname, now.strftime(fmt))


def warn(msg):
    print("WARN: %s" % msg)


def _dump_cmd(cmd):
    print(cmd)
    print("-" * len(cmd))
    print()
    try:
        subprocess.check_call(cmd, shell=True)
        print()
    except subprocess.CalledProcessError as e:
        print("*** Failed to run '%(cmd)s': %(err)s" % {'cmd': cmd, 'err': e})


def _find_cmd(cmd):
    if not shutil.which(cmd):
        print("*** %s not found: skipping" % cmd)
        return False
    return True


def _header(name):
    print()
    print(name)
    print("=" * len(name))
    print()


def _bridge_list():
    process = subprocess.Popen(['sudo', 'ovs-vsctl', 'list-br'],
                               stdout=subprocess.PIPE)
    stdout, _ = process.communicate()
    return stdout.split()


# This method gets a max openflow version supported by openvswitch.
# For example 'ovs-ofctl --version' displays the following:
#
#     ovs-ofctl (Open vSwitch) 2.0.2
#     Compiled Dec  9 2015 14:08:08
#     OpenFlow versions 0x1:0x4
#
# The above shows that openvswitch supports from OpenFlow10 to OpenFlow13.
# This method gets max version searching 'OpenFlow versions 0x1:0x'.
# And return a version value converted to an integer type.
def _get_ofp_version():
    process = subprocess.Popen(['ovs-ofctl', '--version'],
                               stdout=subprocess.PIPE)
    stdout, _ = process.communicate()
    find_str = b'OpenFlow versions 0x1:0x'
    offset = stdout.find(find_str)
    return int(stdout[offset + len(find_str):-1]) - 1


def disk_space():
    # the df output
    _header("File System Summary")

    dfraw = os.popen("df -Ph").read()
    df = [s.split() for s in dfraw.splitlines()]
    for fs in df:
        try:
            if int(fs[4][:-1]) > 95:
                warn("Device %s (%s) is %s full, might be an issue" % (
                    fs[0], fs[5], fs[4]))
        except ValueError:
            # if it doesn't look like an int, that's fine
            pass

    print(dfraw)


def ebtables_dump():
    tables = ['filter', 'nat']
    _header("EB Tables Dump")
    if not _find_cmd('ebtables'):
        return
    for table in tables:
        _dump_cmd("sudo ebtables -t %s -L" % table)


def iptables_dump():
    tables = ['filter', 'nat', 'mangle']
    _header("IP Tables Dump")

    for table in tables:
        _dump_cmd("sudo iptables --line-numbers -L -nv -t %s" % table)


def _netns_list():
    process = subprocess.Popen(['ip', 'netns'], stdout=subprocess.PIPE)
    stdout, _ = process.communicate()
    # NOTE(jlvillal): Sometimes 'ip netns list' can return output like:
    #   qrouter-0805fd7d-c493-4fa6-82ca-1c6c9b23cd9e (id: 1)
    #   qdhcp-bb2cc6ae-2ae8-474f-adda-a94059b872b5 (id: 0)
    output = [x.split()[0] for x in stdout.splitlines()]
    return output


def network_dump():
    _header("Network Dump")

    _dump_cmd("bridge link")
    _dump_cmd("ip link show type bridge")
    ip_cmds = ["neigh", "addr", "route", "-6 route"]
    for cmd in ip_cmds + ['netns']:
        _dump_cmd("ip %s" % cmd)
    for netns_ in _netns_list():
        for cmd in ip_cmds:
            args = {'netns': bytes.decode(netns_), 'cmd': cmd}
            _dump_cmd('sudo ip netns exec %(netns)s ip %(cmd)s' % args)


def ovs_dump():
    _header("Open vSwitch Dump")

    # NOTE(cdent): If we're not using neutron + ovs these commands
    # will not be present so
    if not _find_cmd('ovs-vsctl'):
        return

    bridges = _bridge_list()
    ofctl_cmds = ('show', 'dump-ports-desc', 'dump-ports', 'dump-flows')
    ofp_max = _get_ofp_version()
    vers = 'OpenFlow10'
    for i in range(1, ofp_max + 1):
        vers += ',OpenFlow1' + str(i)
    _dump_cmd("sudo ovs-vsctl show")
    for ofctl_cmd in ofctl_cmds:
        for bridge in bridges:
            args = {'vers': vers, 'cmd': ofctl_cmd, 'bridge': bytes.decode(bridge)}
            _dump_cmd("sudo ovs-ofctl --protocols=%(vers)s %(cmd)s %(bridge)s" % args)


def process_list():
    _header("Process Listing")
    _dump_cmd("ps axo "
              "user,ppid,pid,pcpu,pmem,vsz,rss,tty,stat,start,time,args")


def compute_consoles():
    _header("Compute consoles")
    for root, _, filenames in os.walk('/opt/stack'):
        for filename in fnmatch.filter(filenames, 'console.log'):
            fullpath = os.path.join(root, filename)
            _dump_cmd("sudo cat %s" % fullpath)


def guru_meditation_reports():
    for service in GMR_PROCESSES:
        _header("%s Guru Meditation Report" % service)

        try:
            subprocess.check_call(['pgrep', '-f', service])
        except subprocess.CalledProcessError:
            print("Skipping as %s does not appear to be running" % service)
            continue

        _dump_cmd("killall -e -USR2 %s" % service)
        print("guru meditation report in %s log" % service)


def var_core():
    if os.path.exists('/var/core'):
        _header("/var/core dumps")
        # NOTE(ianw) : see DEBUG_LIBVIRT_COREDUMPS.  We could think
        # about getting backtraces out of these.  There are other
        # tools out there that can do that sort of thing though.
        _dump_cmd("ls -ltrah /var/core")


def disable_stdio_buffering():
    # re-open STDOUT as binary, then wrap it in a
    # TextIOWrapper, and write through everything.
    binary_stdout = io.open(sys.stdout.fileno(), 'wb', 0)
    sys.stdout = io.TextIOWrapper(binary_stdout, write_through=True)


def main():
    opts = get_options()
    fname = filename(opts.dir, opts.name)
    print("World dumping... see %s for details" % fname)

    disable_stdio_buffering()

    with io.open(fname, 'w') as f:
        os.dup2(f.fileno(), sys.stdout.fileno())
        disk_space()
        process_list()
        network_dump()
        ovs_dump()
        iptables_dump()
        ebtables_dump()
        compute_consoles()
        guru_meditation_reports()
        var_core()
    # Singular name for ease of log retrieval
    copyname = os.path.join(opts.dir, 'worlddump')
    if opts.name:
        copyname += '-' + opts.name
    copyname += '-latest.txt'
    # We make a full copy to deal with jobs that may or may not
    # gzip logs breaking symlinks.
    shutil.copyfile(fname, copyname)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(1)
