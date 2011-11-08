#!/bin/bash

EXECUTOR_NUMBER=$1
CONFIGURATION=$2

function usage() {
    echo "Usage: $0 -  Build a configuration"
    echo ""
    echo "$0 [EXECUTOR_NUMBER] [CONFIGURATION]"
    exit 1
}

# Validate inputs
if [[ "$EXECUTOR_NUMBER" = "" || "$CONFIGURATION" = "" ]]; then
    usage
fi

# Execute configuration script
cd configurations && ./$CONFIGURATION.sh $EXECUTOR_NUMBER $CONFIGURATION
