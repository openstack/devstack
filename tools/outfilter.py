#!/usr/bin/env python3

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

# This is an output filter to filter and timestamp the logs from Grenade and
# DevStack. Largely our awk filters got beyond the complexity level which were
# sustainable, so this provides us much more control in a single place.
#
# The overhead of running python should be less than execing `date` a million
# times during a run.

import argparse
import datetime
import re
import sys

IGNORE_LINES = re.compile('(set \+o|xtrace)')
HAS_DATE = re.compile('^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}.\d{3} \|')


def get_options():
    parser = argparse.ArgumentParser(
        description='Filter output by DevStack and friends')
    parser.add_argument('-o', '--outfile',
                        help='Output file for content',
                        default=None)
    # NOTE(ianw): This is intended for the case where your stdout is
    # being captured by something like ansible which independently
    # logs timestamps on the lines it receives.  Note that if using a
    # output file, those log lines are still timestamped.
    parser.add_argument('-b', '--no-timestamp', action='store_true',
                        help='Do not prefix stdout with timestamp (bare)',
                        default=False)
    parser.add_argument('-v', '--verbose', action='store_true',
                        default=False)
    return parser.parse_args()


def skip_line(line):
    """Should we skip this line."""
    return IGNORE_LINES.search(line) is not None


def main():
    opts = get_options()
    outfile = None
    if opts.outfile:
        # note, binary mode so we can do unbuffered output.
        outfile = open(opts.outfile, 'ab', 0)

    # Otherwise fileinput reprocess args as files
    sys.argv = []

    for line in iter(sys.stdin.readline, ''):
        # put skip lines here
        if skip_line(line):
            continue

        # This prevents us from nesting date lines, because we'd like
        # to pull this in directly in Grenade and not double up on
        # DevStack lines.
        # NOTE(ianw): we could actually strip the extra ts in "bare"
        # mode (which came after this)? ... as we get more experience
        # with zuulv3 native jobs and ansible capture it may become
        # clearer what to do
        if HAS_DATE.search(line) is None:
            now = datetime.datetime.utcnow()
            ts_line = ("%s | %s" % (
                now.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3],
                line))
        else:
            ts_line = line

        if opts.verbose:
            sys.stdout.write(line if opts.no_timestamp else ts_line)
            sys.stdout.flush()

        if outfile:
            # We've opened outfile as a binary file to get the
            # non-buffered behaviour.  on python3, sys.stdin was
            # opened with the system encoding and made the line into
            # utf-8, so write the logfile out in utf-8 bytes.
            if sys.version_info < (3,):
                outfile.write(ts_line)
            else:
                outfile.write(ts_line.encode('utf-8'))
            outfile.flush()


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(1)
