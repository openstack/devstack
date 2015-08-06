#!/usr/bin/env python
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
import os
import os.path
import subprocess
import sys


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
    now = datetime.datetime.utcnow()
    fmt = "worlddump-%Y-%m-%d-%H%M%S"
    if name:
        fmt += "-" + name
    fmt += ".txt"
    return os.path.join(dirname, now.strftime(fmt))


def warn(msg):
    print "WARN: %s" % msg


def _dump_cmd(cmd):
    print cmd
    print "-" * len(cmd)
    print
    try:
        subprocess.check_call(cmd, shell=True)
    except subprocess.CalledProcessError:
        print "*** Failed to run: %s" % cmd


def _header(name):
    print
    print name
    print "=" * len(name)
    print


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

    print dfraw


def ebtables_dump():
    _header("EB Tables Dump")
    _dump_cmd("sudo ebtables -L")


def iptables_dump():
    tables = ['filter', 'nat', 'mangle']
    _header("IP Tables Dump")

    for table in tables:
        _dump_cmd("sudo iptables --line-numbers -L -nv -t %s" % table)


def network_dump():
    _header("Network Dump")

    _dump_cmd("brctl show")
    _dump_cmd("arp -n")
    _dump_cmd("ip addr")
    _dump_cmd("ip link")
    _dump_cmd("ip route")


def process_list():
    _header("Process Listing")
    _dump_cmd("ps axo "
              "user,ppid,pid,pcpu,pmem,vsz,rss,tty,stat,start,time,args")


def compute_consoles():
    _header("Compute consoles")
    for root, dirnames, filenames in os.walk('/opt/stack'):
        for filename in fnmatch.filter(filenames, 'console.log'):
            fullpath = os.path.join(root, filename)
            _dump_cmd("sudo cat %s" % fullpath)


def guru_meditation_report():
    _header("nova-compute Guru Meditation Report")

    try:
        subprocess.check_call(["pgrep","nova-compute"])
    except subprocess.CalledProcessError:
        print "Skipping as nova-compute does not appear to be running"
        return

    _dump_cmd("kill -s USR1 `pgrep nova-compute`")
    print "guru meditation report in nova-compute log"


def main():
    opts = get_options()
    fname = filename(opts.dir, opts.name)
    print "World dumping... see %s for details" % fname
    sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', 0)
    with open(fname, 'w') as f:
        os.dup2(f.fileno(), sys.stdout.fileno())
        disk_space()
        process_list()
        network_dump()
        iptables_dump()
        ebtables_dump()
        compute_consoles()
        guru_meditation_report()


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(1)
