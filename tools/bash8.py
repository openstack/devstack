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
# Basic white space errors, for consistent indenting
# - E001: check that lines do not end with trailing whitespace
# - E002: ensure that indents are only spaces, and not hard tabs
# - E003: ensure all indents are a multiple of 4 spaces
#
# Structure errors
#
# A set of rules that help keep things consistent in control blocks.
# These are ignored on long lines that have a continuation, because
# unrolling that is kind of "interesting"
#
# - E010: *do* not on the same line as *for*
# - E011: *then* not on the same line as *if*

import argparse
import fileinput
import re
import sys

ERRORS = 0
IGNORE = None


def register_ignores(ignores):
    global IGNORE
    if ignores:
        IGNORE='^(' + '|'.join(ignores.split(',')) + ')'


def should_ignore(error):
    return IGNORE and re.search(IGNORE, error)


def print_error(error, line):
    global ERRORS
    ERRORS = ERRORS + 1
    print("%s: '%s'" % (error, line.rstrip('\n')))
    print(" - %s: L%s" % (fileinput.filename(), fileinput.filelineno()))


def not_continuation(line):
    return not re.search('\\\\$', line)

def check_for_do(line):
    if not_continuation(line):
        if re.search('^\s*for ', line):
            if not re.search(';\s*do(\b|$)', line):
                print_error('E010: Do not on same line as for', line)


def check_if_then(line):
    if not_continuation(line):
        if re.search('^\s*if \[', line):
            if not re.search(';\s*then(\b|$)', line):
                print_error('E011: Then non on same line as if', line)


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


def starts_multiline(line):
    m = re.search("[^<]<<\s*(?P<token>\w+)", line)
    if m:
        return m.group('token')
    else:
        return False


def end_of_multiline(line, token):
    if token:
        return re.search("^%s\s*$" % token, line) is not None
    return False


def check_files(files):
    in_multiline = False
    logical_line = ""
    token = False
    for line in fileinput.input(files):
        # NOTE(sdague): multiline processing of heredocs is interesting
        if not in_multiline:
            logical_line = line
            token = starts_multiline(line)
            if token:
                in_multiline = True
                continue
        else:
            logical_line = logical_line + line
            if not end_of_multiline(line, token):
                continue
            else:
                in_multiline = False

        check_no_trailing_whitespace(logical_line)
        check_indents(logical_line)
        check_for_do(logical_line)
        check_if_then(logical_line)


def get_options():
    parser = argparse.ArgumentParser(
        description='A bash script style checker')
    parser.add_argument('files', metavar='file', nargs='+',
                        help='files to scan for errors')
    parser.add_argument('-i', '--ignore', help='Rules to ignore')
    return parser.parse_args()


def main():
    opts = get_options()
    register_ignores(opts.ignore)
    check_files(opts.files)

    if ERRORS > 0:
        print("%d bash8 error(s) found" % ERRORS)
        return 1
    else:
        return 0


if __name__ == "__main__":
    sys.exit(main())
