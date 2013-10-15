#!/usr/bin/env python
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

# bash8 - a pep8 equivalent for bash scripts
#
# this program attempts to be an automated style checker for bash scripts
# to fill the same part of code review that pep8 does in most OpenStack
# projects. It starts from humble beginnings, and will evolve over time.
#
# Currently Supported checks
#
# Errors
# - E001: check that lines do not end with trailing whitespace
# - E002: ensure that indents are only spaces, and not hard tabs
# - E003: ensure all indents are a multiple of 4 spaces

import argparse
import fileinput
import re
import sys


ERRORS = 0


def print_error(error, line):
    global ERRORS
    ERRORS = ERRORS + 1
    print("%s: '%s'" % (error, line.rstrip('\n')))
    print(" - %s: L%s" % (fileinput.filename(), fileinput.filelineno()))


def check_no_trailing_whitespace(line):
    if re.search('[ \t]+$', line):
        print_error('E001: Trailing Whitespace', line)


def check_indents(line):
    m = re.search('^(?P<indent>[ \t]+)', line)
    if m:
        if re.search('\t', m.group('indent')):
            print_error('E002: Tab indents', line)
        if (len(m.group('indent')) % 4) != 0:
            print_error('E003: Indent not multiple of 4', line)


def check_files(files):
    for line in fileinput.input(files):
        check_no_trailing_whitespace(line)
        check_indents(line)


def get_options():
    parser = argparse.ArgumentParser(
        description='A bash script style checker')
    parser.add_argument('files', metavar='file', nargs='+',
                        help='files to scan for errors')
    return parser.parse_args()


def main():
    opts = get_options()
    check_files(opts.files)

    if ERRORS > 0:
        print("%d bash8 error(s) found" % ERRORS)
        return 1
    else:
        return 0


if __name__ == "__main__":
    sys.exit(main())
