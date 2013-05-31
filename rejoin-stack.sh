#! /usr/bin/env bash

# This script rejoins an existing screen, or re-creates a
# screen session from a previous run of stack.sh.

TOP_DIR=`dirname $0`

source $TOP_DIR/stackrc

# if screenrc exists, run screen
if [[ -e $TOP_DIR/stack-screenrc ]]; then
    if screen -ls | egrep -q "[0-9].stack"; then
        echo "Attaching to already started screen session.."
        exec screen -r stack
    fi
    exec screen -c $TOP_DIR/stack-screenrc -S $SCREEN_NAME
fi

echo "Couldn't find $TOP_DIR/stack-screenrc file; have you run stack.sh yet?"
exit 1
