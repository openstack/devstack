#!/bin/bash

EXECUTOR_NUMBER=$1
ADAPTER=$2

function usage() {
    echo "Usage: $0 - Run a test"
    echo ""
    echo "$0 [EXECUTOR_NUMBER] [ADAPTER]"
    exit 1
}

# Validate inputs
if [[ "$EXECUTOR_NUMBER" = "" || "$ADAPTER" = "" ]]; then
    usage
fi

# Execute configuration script
cd adapters && ./$ADAPTER.sh $EXECUTOR_NUMBER $ADAPTER
