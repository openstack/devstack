#!/bin/bash -ex

# Copyright 2016 Hewlett Packard Enterprise Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# This script is intended to be run as a periodic proposal bot job
# in OpenStack infrastructure, though you can run it as a one-off.
#
# In order to function correctly, the environment in which the
# script runs must have
#   * a writable doc/source directory relative to the current
#     working directory
#   AND ( (
#   * git
#   * all git repos meant to be searched for plugins cloned and
#     at the desired level of up-to-datedness
#   * the environment variable git_dir pointing to the location
#   * of said git repositories
#   ) OR (
#   * network access to the review.opendev.org Gerrit API
#     working directory
#   * network access to https://opendev.org
#   ))
#
# If a file named data/devstack-plugins-registry.header or
# data/devstack-plugins-registry.footer is found relative to the
# current working directory, it will be prepended or appended to
# the generated reStructuredText plugins table respectively.

# Print the title underline for a RST table.  Argument is the length
# of the first column, second column is assumed to be "URL"
function title_underline {
    local len=$1
    while [[ $len -gt 0 ]]; do
        printf "="
        len=$(( len - 1))
    done
    printf " ===\n"
}

(
if [[ -r data/devstack-plugins-registry.header ]]; then
    cat data/devstack-plugins-registry.header
fi

sorted_plugins=$(python3 tools/generate-devstack-plugins-list.py)

# find the length of the name column & pad
name_col_len=$(echo "${sorted_plugins}" | wc -L)
name_col_len=$(( name_col_len + 2 ))

# ====================== ===
# Plugin Name            URL
# ====================== ===
# foobar                 `https://... <https://...>`__
# ...

printf "\n\n"
title_underline ${name_col_len}
printf "%-${name_col_len}s %s\n" "Plugin Name" "URL"
title_underline ${name_col_len}

for plugin in ${sorted_plugins}; do
    giturl="https://opendev.org/${plugin}"
    gitlink="https://opendev.org/${plugin}"
    printf "%-${name_col_len}s %s\n" "${plugin}" "\`${giturl} <${gitlink}>\`__"
done

title_underline ${name_col_len}

printf "\n\n"

if [[ -r data/devstack-plugins-registry.footer ]]; then
    cat data/devstack-plugins-registry.footer
fi
) > doc/source/plugin-registry.rst

if [[ -n ${1} ]]; then
    cp doc/source/plugin-registry.rst ${1}/doc/source/plugin-registry.rst
fi
