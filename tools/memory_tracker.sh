#!/bin/bash
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

set -o errexit

# TODO(frickler): make this use stackrc variables
if [ -x /opt/stack/data/venv/bin/python ]; then
    PYTHON=/opt/stack/data/venv/bin/python
else
    PYTHON=${PYTHON:-python3}
fi

# time to sleep between checks
SLEEP_TIME=20

# MemAvailable is the best estimation and has built-in heuristics
# around reclaimable memory.  However, it is not available until 3.14
# kernel (i.e. Ubuntu LTS Trusty misses it).  In that case, we fall
# back to free+buffers+cache as the available memory.
USE_MEM_AVAILABLE=0
if grep -q '^MemAvailable:' /proc/meminfo; then
    USE_MEM_AVAILABLE=1
fi

function get_mem_unevictable {
    awk '/^Unevictable:/ {print $2}' /proc/meminfo
}

function get_mem_available {
    if [[ $USE_MEM_AVAILABLE -eq 1 ]]; then
        awk '/^MemAvailable:/ {print $2}' /proc/meminfo
    else
        awk '/^MemFree:/ {free=$2}
            /^Buffers:/ {buffers=$2}
            /^Cached:/  {cached=$2}
            END { print free+buffers+cached }' /proc/meminfo
    fi
}

function tracker {
    local low_point
    local unevictable_point
    low_point=$(get_mem_available)
    # log mlocked memory at least on first iteration
    unevictable_point=0
    while [ 1 ]; do

        local mem_available
        mem_available=$(get_mem_available)

        local unevictable
        unevictable=$(get_mem_unevictable)

        if [ $mem_available -lt $low_point -o $unevictable -ne $unevictable_point ]; then
            echo "[[["
            date

            # whenever we see less memory available than last time, dump the
            # snapshot of current usage; i.e. checking the latest entry in the file
            # will give the peak-memory usage
            if [[ $mem_available -lt $low_point ]]; then
                low_point=$mem_available
                echo "---"
                # always available greppable output; given difference in
                # meminfo output as described above...
                echo "memory_tracker low_point: $mem_available"
                echo "---"
                cat /proc/meminfo
                echo "---"
                # would hierarchial view be more useful (-H)?  output is
                # not sorted by usage then, however, and the first
                # question is "what's using up the memory"
                #
                # there are a lot of kernel threads, especially on a 8-cpu
                # system.  do a best-effort removal to improve
                # signal/noise ratio of output.
                ps --sort=-pmem -eo pid:10,pmem:6,rss:15,ppid:10,cputime:10,nlwp:8,wchan:25,args:100 |
                    grep -v ']$'
            fi
            echo "---"

            # list processes that lock memory from swap
            if [[ $unevictable -ne $unevictable_point ]]; then
                unevictable_point=$unevictable
                ${PYTHON} $(dirname $0)/mlock_report.py
            fi

            echo "]]]"
        fi
        sleep $SLEEP_TIME
    done
}

function usage {
    echo "Usage: $0 [-x] [-s N]" 1>&2
    exit 1
}

while getopts ":s:x" opt; do
    case $opt in
        s)
            SLEEP_TIME=$OPTARG
            ;;
        x)
            set -o xtrace
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

tracker
