#! /usr/bin/env bash

# This script rejoins an existing screen, or re-creates a
# screen session from a previous run of stack.sh.

TOP_DIR=`dirname $0`

# Import common functions in case the localrc (loaded via stackrc)
# uses them.
source $TOP_DIR/functions

source $TOP_DIR/stackrc

SCREENRC=$TOP_DIR/$SCREEN_NAME-screenrc
# if screenrc exists, run screen
if [[ -e $SCREENRC ]]; then
    if screen -ls | egrep -q "[0-9]+.${SCREEN_NAME}"; then
        echo "Attaching to already started screen session.."
        exec screen -r $SCREEN_NAME
    fi
    exec screen -c $SCREENRC
fi

echo "Couldn't find $SCREENRC file; have you run stack.sh yet?"
exit 1
