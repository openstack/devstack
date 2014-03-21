#!/usr/bin/python

#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

import json
import sys
import urllib


def print_usage():
    print("Usage: %s [jenkins_url (eg. http://50.56.12.202:8080/)]"
          % sys.argv[0])
    sys.exit()


def fetch_blob(url):
    return json.loads(urllib.urlopen(url + '/api/json').read())


if len(sys.argv) < 2:
    print_usage()

BASE_URL = sys.argv[1]

root = fetch_blob(BASE_URL)
results = {}
for job_url in root['jobs']:
    job = fetch_blob(job_url['url'])
    if job.get('activeConfigurations'):
        (tag, name) = job['name'].split('-')
        if not results.get(tag):
            results[tag] = {}
        if not results[tag].get(name):
            results[tag][name] = []

        for config_url in job['activeConfigurations']:
            config = fetch_blob(config_url['url'])

            log_url = ''
            if config.get('lastBuild'):
                log_url = config['lastBuild']['url'] + 'console'

            results[tag][name].append({'test': config['displayName'],
                                       'status': config['color'],
                                       'logUrl': log_url,
                                       'healthReport': config['healthReport']})

print(json.dumps(results))
