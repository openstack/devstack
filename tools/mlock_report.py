#!/usr/bin/env python

# This tool lists processes that lock memory pages from swapping to disk.

import re
import subprocess

import psutil


SUMMARY_REGEX = re.compile(r".*\s+(?P<locked>[\d]+)\s+KB")


def main():
    try:
        print _get_report()
    except Exception as e:
        print "Failure listing processes locking memory: %s" % str(e)


def _get_report():
    mlock_users = []
    for proc in psutil.process_iter():
        pid = proc.pid
        # sadly psutil does not expose locked pages info, that's why we
        # call to pmap and parse the output here
        try:
            out = subprocess.check_output(['pmap', '-XX', str(pid)])
        except subprocess.CalledProcessError as e:
            # 42 means process just vanished, which is ok
            if e.returncode == 42:
                continue
            raise
        last_line = out.splitlines()[-1]

        # some processes don't provide a memory map, for example those
        # running as kernel services, so we need to skip those that don't
        # match
        result = SUMMARY_REGEX.match(last_line)
        if result:
            locked = int(result.group('locked'))
            if locked:
                mlock_users.append({'name': proc.name(),
                                    'pid': pid,
                                    'locked': locked})

    # produce a single line log message with per process mlock stats
    if mlock_users:
        return "; ".join(
            "[%(name)s (pid:%(pid)s)]=%(locked)dKB" % args
            # log heavy users first
            for args in sorted(mlock_users, key=lambda d: d['locked'])
        )
    else:
        return "no locked memory"


if __name__ == "__main__":
    main()
