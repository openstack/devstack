#!/bin/bash

EXECUTOR_NUMBER=$1
CONFIGURATION=$2
ADAPTER=$3
RC=$4

function usage {
    echo "Usage: $0 -  Build a configuration"
    echo ""
    echo "$0 [EXECUTOR_NUMBER] [CONFIGURATION] [ADAPTER] [RC (optional)]"
    exit 1
}

# Validate inputs
if [[ "$EXECUTOR_NUMBER" = "" || "$CONFIGURATION" = ""  || "$ADAPTER" = "" ]]; then
    usage
fi

# Execute configuration script
cd configurations && ./$CONFIGURATION.sh $EXECUTOR_NUMBER $CONFIGURATION $ADAPTER "$RC"
