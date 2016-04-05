#! /usr/bin/env python

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

# This script is intended to be run as part of a periodic proposal bot
# job in OpenStack infrastructure.
#
# In order to function correctly, the environment in which the
# script runs must have
#   * network access to the review.openstack.org Gerrit API
#     working directory
#   * network access to https://git.openstack.org/cgit

import logging
import json
import requests

logging.basicConfig(level=logging.DEBUG)

url = 'https://review.openstack.org/projects/'

# This is what a project looks like
'''
  "openstack-attic/akanda": {
    "id": "openstack-attic%2Fakanda",
    "state": "READ_ONLY"
  },
'''

def is_in_openstack_namespace(proj):
    # only interested in openstack namespace (e.g. not retired
    # stackforge, etc)
    return proj.startswith('openstack/')

# Rather than returning a 404 for a nonexistent file, cgit delivers a
# 0-byte response to a GET request.  It also does not provide a
# Content-Length in a HEAD response, so the way we tell if a file exists
# is to check the length of the entire GET response body.
def has_devstack_plugin(proj):
    r = requests.get("https://git.openstack.org/cgit/%s/plain/devstack/plugin.sh" % proj)
    if len(r.text) > 0:
        return True
    else:
        return False

logging.debug("Getting project list from %s" % url)
r = requests.get(url)
projects = sorted(filter(is_in_openstack_namespace, json.loads(r.text[4:])))
logging.debug("Found %d projects" % len(projects))

found_plugins = filter(has_devstack_plugin, projects)

for project in found_plugins:
    # strip of openstack/
    print(project[10:])
