#!/usr/bin/python3

import argparse
import csv
import datetime
import glob
import itertools
import json
import logging
import os
import re
import socket
import subprocess
import sys

try:
    import psutil
except ImportError:
    psutil = None
    print('No psutil, process information will not be included',
          file=sys.stderr)

try:
    import pymysql
except ImportError:
    pymysql = None
    print('No pymysql, database information will not be included',
          file=sys.stderr)

LOG = logging.getLogger('perf')

# https://www.elastic.co/blog/found-crash-elasticsearch#mapping-explosion


def tryint(value):
    try:
        return int(value)
    except (ValueError, TypeError):
        return value


def get_service_stats(service):
    stats = {'MemoryCurrent': 0}
    output = subprocess.check_output(['/usr/bin/systemctl', 'show', service] +
                                     ['-p%s' % stat for stat in stats])
    for line in output.decode().split('\n'):
        if not line:
            continue
        stat, val = line.split('=')
        stats[stat] = tryint(val)

    return stats


def get_services_stats():
    services = [os.path.basename(s) for s in
                glob.glob('/etc/systemd/system/devstack@*.service')] + \
                ['apache2.service']
    return [dict(service=service, **get_service_stats(service))
            for service in services]


def get_process_stats(proc):
    cmdline = proc.cmdline()
    if 'python' in cmdline[0]:
        cmdline = cmdline[1:]
    return {'cmd': cmdline[0],
            'pid': proc.pid,
            'args': ' '.join(cmdline[1:]),
            'rss': proc.memory_info().rss}


def get_processes_stats(matches):
    me = os.getpid()
    procs = psutil.process_iter()

    def proc_matches(proc):
        return me != proc.pid and any(
            re.search(match, ' '.join(proc.cmdline()))
            for match in matches)

    return [
        get_process_stats(proc)
        for proc in procs
        if proc_matches(proc)]


def get_db_stats(host, user, passwd):
    dbs = []
    try:
        db = pymysql.connect(host=host, user=user, password=passwd,
                             database='stats',
                             cursorclass=pymysql.cursors.DictCursor)
    except pymysql.err.OperationalError as e:
        if 'Unknown database' in str(e):
            print('No stats database; assuming devstack failed',
                  file=sys.stderr)
            return []
        raise

    with db:
        with db.cursor() as cur:
            cur.execute('SELECT db,op,count FROM queries')
            for row in cur:
                dbs.append({k: tryint(v) for k, v in row.items()})
    return dbs


def get_http_stats_for_log(logfile):
    stats = {}
    apache_fields = ('host', 'a', 'b', 'date', 'tz', 'request', 'status',
                     'length', 'c', 'agent')
    ignore_agents = ('curl', 'uwsgi', 'nova-status')
    ignored_services = set()
    for line in csv.reader(open(logfile), delimiter=' '):
        fields = dict(zip(apache_fields, line))
        if len(fields) != len(apache_fields):
            # Not a combined access log, so we can bail completely
            return []
        try:
            method, url, http = fields['request'].split(' ')
        except ValueError:
            method = url = http = ''
        if 'HTTP' not in http:
            # Not a combined access log, so we can bail completely
            return []

        # Tempest's User-Agent is unchanged, but client libraries and
        # inter-service API calls use proper strings. So assume
        # 'python-urllib' is tempest so we can tell it apart.
        if 'python-urllib' in fields['agent'].lower():
            agent = 'tempest'
        else:
            agent = fields['agent'].split(' ')[0]
            if agent.startswith('python-'):
                agent = agent.replace('python-', '')
            if '/' in agent:
                agent = agent.split('/')[0]

        if agent in ignore_agents:
            continue

        try:
            service, rest = url.strip('/').split('/', 1)
        except ValueError:
            # Root calls like "GET /identity"
            service = url.strip('/')
            rest = ''

        if not service.isalpha():
            ignored_services.add(service)
            continue

        method_key = '%s-%s' % (agent, method)
        try:
            length = int(fields['length'])
        except ValueError:
            LOG.warning('[%s] Failed to parse length %r from line %r' % (
                logfile, fields['length'], line))
            length = 0
        stats.setdefault(service, {'largest': 0})
        stats[service].setdefault(method_key, 0)
        stats[service][method_key] += 1
        stats[service]['largest'] = max(stats[service]['largest'],
                                        length)

    if ignored_services:
        LOG.warning('Ignored services: %s' % ','.join(
            sorted(ignored_services)))

    # Flatten this for ES
    return [{'service': service, 'log': os.path.basename(logfile),
             **vals}
            for service, vals in stats.items()]


def get_http_stats(logfiles):
    return list(itertools.chain.from_iterable(get_http_stats_for_log(log)
                                              for log in logfiles))


def get_report_info():
    return {
        'timestamp': datetime.datetime.now().isoformat(),
        'hostname': socket.gethostname(),
        'version': 2,
    }


if __name__ == '__main__':
    process_defaults = ['privsep', 'mysqld', 'erlang', 'etcd']
    parser = argparse.ArgumentParser()
    parser.add_argument('--db-user', default='root',
                        help=('MySQL user for collecting stats '
                              '(default: "root")'))
    parser.add_argument('--db-pass', default=None,
                        help='MySQL password for db-user')
    parser.add_argument('--db-host', default='localhost',
                        help='MySQL hostname')
    parser.add_argument('--apache-log', action='append', default=[],
                        help='Collect API call stats from this apache log')
    parser.add_argument('--process', action='append',
                        default=process_defaults,
                        help=('Include process stats for this cmdline regex '
                              '(default is %s)' % ','.join(process_defaults)))
    args = parser.parse_args()

    logging.basicConfig(level=logging.WARNING)

    data = {
        'services': get_services_stats(),
        'db': pymysql and args.db_pass and get_db_stats(args.db_host,
                                                        args.db_user,
                                                        args.db_pass) or [],
        'processes': psutil and get_processes_stats(args.process) or [],
        'api': get_http_stats(args.apache_log),
        'report': get_report_info(),
    }

    print(json.dumps(data, indent=2))
