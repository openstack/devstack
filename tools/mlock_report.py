# This tool lists processes that lock memory pages from swapping to disk.

import re

import psutil


LCK_SUMMARY_REGEX = re.compile(
    "^VmLck:\s+(?P<locked>[\d]+)\s+kB", re.MULTILINE)


def main():
    try:
        print(_get_report())
    except Exception as e:
        print("Failure listing processes locking memory: %s" % str(e))
        raise


def _get_report():
    mlock_users = []
    for proc in psutil.process_iter():
        # sadly psutil does not expose locked pages info, that's why we
        # iterate over the /proc/%pid/status files manually
        try:
            s = open("%s/%d/status" % (psutil.PROCFS_PATH, proc.pid), 'r')
            with s:
                for line in s:
                    result = LCK_SUMMARY_REGEX.search(line)
                    if result:
                        locked = int(result.group('locked'))
                        if locked:
                            mlock_users.append({'name': proc.name(),
                                                'pid': proc.pid,
                                                'locked': locked})
        except OSError:
            # pids can disappear, we're ok with that
            continue


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
