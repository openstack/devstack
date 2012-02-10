#!/usr/bin/python
import urllib
import json
import sys


def print_usage():
    print ("Usage: %s [jenkins_url (eg. http://50.56.12.202:8080/)]"
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

print json.dumps(results)
