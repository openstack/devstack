#!/usr/bin/env bash

# Run everything in the exercises/ directory that isn't explicitly disabled

# comma separated list of script basenames to skip
# to refrain from exercising euca.sh use SKIP_EXERCISES=euca
SKIP_EXERCISES=${SKIP_EXERCISES:-""}

EXERCISE_DIR=$(dirname "$0")/exercises
basenames=$(for b in `ls $EXERCISE_DIR/*.sh` ; do basename $b .sh ; done)

for script in $basenames ; do
    if [[ "$SKIP_EXERCISES" =~ $script ]] ; then
        echo SKIPPING $script
    else
        echo Running $script
        $EXERCISE_DIR/$script.sh 2> $script.log
        if [[ $? -ne 0 ]] ; then
            echo FAILED.  See $script.log
        else
            rm $script.log
        fi
    fi
done
