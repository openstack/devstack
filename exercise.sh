#!/usr/bin/env bash

# **exercise.sh**

# Keep track of the current DevStack directory.
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $TOP_DIR/functions

# Load local configuration
source $TOP_DIR/stackrc

# Run everything in the exercises/ directory that isn't explicitly disabled

# comma separated list of script basenames to skip
# to refrain from exercising foo.sh use ``SKIP_EXERCISES=foo``
SKIP_EXERCISES=${SKIP_EXERCISES:-""}

# comma separated list of script basenames to run
# to run only foo.sh use ``RUN_EXERCISES=foo``
basenames=${RUN_EXERCISES:-""}

EXERCISE_DIR=$TOP_DIR/exercises

if [[ -z "${basenames}" ]]; then
    # Locate the scripts we should run
    basenames=$(for b in `ls $EXERCISE_DIR/*.sh`; do basename $b .sh; done)
else
    # If ``RUN_EXERCISES`` was specified, ignore ``SKIP_EXERCISES``.
    SKIP_EXERCISES=
fi

# Track the state of each script
passes=""
failures=""
skips=""

# Loop over each possible script (by basename)
for script in $basenames; do
    if [[ ,$SKIP_EXERCISES, =~ ,$script, ]]; then
        skips="$skips $script"
    else
        echo "====================================================================="
        echo Running $script
        echo "====================================================================="
        $EXERCISE_DIR/$script.sh
        exitcode=$?
        if [[ $exitcode == 55 ]]; then
            skips="$skips $script"
        elif [[ $exitcode -ne 0 ]]; then
            failures="$failures $script"
        else
            passes="$passes $script"
        fi
    fi
done

# Output status of exercise run
echo "====================================================================="
for script in $skips; do
    echo SKIP $script
done
for script in $passes; do
    echo PASS $script
done
for script in $failures; do
    echo FAILED $script
done
echo "====================================================================="

if [[ -n "$failures" ]]; then
    exit 1
fi
