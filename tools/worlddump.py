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
import os
import os.path
import sys


def get_options():
    parser = argparse.ArgumentParser(
        description='Dump world state for debugging')
    parser.add_argument('-d', '--dir',
                        default='.',
                        help='Output directory for worlddump')
    return parser.parse_args()


def filename(dirname):
    now = datetime.datetime.utcnow()
    return os.path.join(dirname, now.strftime("worlddump-%Y-%m-%d-%H%M%S.txt"))


def warn(msg):
    print "WARN: %s" % msg


def disk_space():
    # the df output
    print """
File System Summary
===================
"""
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


def process_list():
    print """
Process Listing
===============
"""
    psraw = os.popen("ps auxw").read()
    print psraw


def main():
    opts = get_options()
    fname = filename(opts.dir)
    print "World dumping... see %s for details" % fname
    sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', 0)
    with open(fname, 'w') as f:
        os.dup2(f.fileno(), sys.stdout.fileno())
        disk_space()
        process_list()


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(1)
