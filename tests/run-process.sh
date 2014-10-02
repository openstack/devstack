#!/bin/bash
# tests/exec.sh - Test DevStack screen_it() and screen_stop()
#
# exec.sh start|stop|status
#
# Set USE_SCREEN to change the default
#
# This script emulates the basic exec envirnment in ``stack.sh`` to test
# the process spawn and kill operations.

if [[ -z $1 ]]; then
    echo "$0 start|stop"
    exit 1
fi

TOP_DIR=$(cd $(dirname "$0")/.. && pwd)
source $TOP_DIR/functions

USE_SCREEN=${USE_SCREEN:-False}

ENABLED_SERVICES=fake-service

SERVICE_DIR=/tmp
SCREEN_NAME=test
SCREEN_LOGDIR=${SERVICE_DIR}/${SCREEN_NAME}


# Kill background processes on exit
trap clean EXIT
clean() {
    local r=$?
    jobs -p
    kill >/dev/null 2>&1 $(jobs -p)
    exit $r
}


# Exit on any errors so that errors don't compound
trap failed ERR
failed() {
    local r=$?
    jobs -p
    kill >/dev/null 2>&1 $(jobs -p)
    set +o xtrace
    [ -n "$LOGFILE" ] && echo "${0##*/} failed: full log in $LOGFILE"
    exit $r
}

function status {
    if [[ -r $SERVICE_DIR/$SCREEN_NAME/fake-service.pid ]]; then
        pstree -pg $(cat $SERVICE_DIR/$SCREEN_NAME/fake-service.pid)
    fi
    ps -ef | grep fake
}

function setup_screen {
if [[ ! -d $SERVICE_DIR/$SCREEN_NAME ]]; then
    rm -rf $SERVICE_DIR/$SCREEN_NAME
    mkdir -p $SERVICE_DIR/$SCREEN_NAME
fi

if [[ "$USE_SCREEN" == "True" ]]; then
    # Create a new named screen to run processes in
    screen -d -m -S $SCREEN_NAME -t shell -s /bin/bash
    sleep 1

    # Set a reasonable status bar
    if [ -z "$SCREEN_HARDSTATUS" ]; then
        SCREEN_HARDSTATUS='%{= .} %-Lw%{= .}%> %n%f %t*%{= .}%+Lw%< %-=%{g}(%{d}%H/%l%{g})'
    fi
    screen -r $SCREEN_NAME -X hardstatus alwayslastline "$SCREEN_HARDSTATUS"
fi

# Clear screen rc file
SCREENRC=$TOP_DIR/tests/$SCREEN_NAME-screenrc
if [[ -e $SCREENRC ]]; then
    echo -n > $SCREENRC
fi
}

# Mimic logging
    # Set up output redirection without log files
    # Copy stdout to fd 3
    exec 3>&1
    if [[ "$VERBOSE" != "True" ]]; then
        # Throw away stdout and stderr
        #exec 1>/dev/null 2>&1
        :
    fi
    # Always send summary fd to original stdout
    exec 6>&3


if [[ "$1" == "start" ]]; then
    echo "Start service"
    setup_screen
    screen_it fake-service "$TOP_DIR/tests/fake-service.sh"
    sleep 1
    status
elif [[ "$1" == "stop" ]]; then
    echo "Stop service"
    screen_stop fake-service
    status
elif [[ "$1" == "status" ]]; then
    status
else
    echo "Unknown command"
    exit 1
fi
