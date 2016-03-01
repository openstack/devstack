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
#   * network access to the review.openstack.org Gerrit API
#     working directory
#   * network access to https://git.openstack.org/cgit
#   ))
#
# If a file named data/devstack-plugins-registry.header or
# data/devstack-plugins-registry.footer is found relative to the
# current working directory, it will be prepended or appended to
# the generated reStructuredText plugins table respectively.

(
declare -A plugins

test -r data/devstack-plugins-registry.header && cat data/devstack-plugins-registry.header

sorted_plugins=$(python tools/generate-devstack-plugins-list.py)

for k in ${sorted_plugins}; do
    project=${k:0:28}
    giturl="git://git.openstack.org/openstack/${k:0:26}"
    printf "|%-28s|%-73s|\n" "${project}" "${giturl}"
    printf "+----------------------------+-------------------------------------------------------------------------+\n"
done

test -r data/devstack-plugins-registry.footer && cat data/devstack-plugins-registry.footer
) > doc/source/plugin-registry.rst

if [[ -n ${1} ]]; then
    cp doc/source/plugin-registry.rst ${1}/doc/source/plugin-registry.rst
fi
