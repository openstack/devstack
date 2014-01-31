#!/usr/bin/env python
#
# Copyright 2014 Samsung Electronics Corp. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

import re
import subprocess
import sys


def is_data_line(line):
    timestamp, data = parse_line(line)
    return re.search('\d\.d', data)


def parse_line(line):
    m = re.search('(\d\d:\d\d:\d\d( \w\w)?)(\s+((\S+)\s*)+)', line)
    if m:
        date = m.group(1)
        data = m.group(3).rstrip()
        return date, data
    else:
        return None, None


process = subprocess.Popen(
    "sar %s" % " ".join(sys.argv[1:]),
    shell=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT)

# Poll process for new output until finished

start_time = ""
header = ""
data_line = ""
printed_header = False
current_ts = None

# print out the first sysstat line regardless
print process.stdout.readline()

while True:
    nextline = process.stdout.readline()
    if nextline == '' and process.poll() is not None:
        break

    date, data = parse_line(nextline)
    # stop until we get to the first set of real lines
    if not date:
        continue

    # now we eat the header lines, and only print out the header
    # if we've never seen them before
    if not start_time:
        start_time = date
        header += "%s   %s" % (date, data)
    elif date == start_time:
        header += "   %s" % data
    elif not printed_header:
        printed_header = True
        print header

    # now we know this is a data line, printing out if the timestamp
    # has changed, and stacking up otherwise.
    nextline = process.stdout.readline()
    date, data = parse_line(nextline)
    if date != current_ts:
        current_ts = date
        print data_line
        data_line = "%s   %s" % (date, data)
    else:
        data_line += "   %s" % data

    sys.stdout.flush()
