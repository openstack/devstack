#!/bin/bash

set -e
set -o xtrace

declare -a on_exit_hooks

on_exit()
{
    for i in $(seq $((${#on_exit_hooks[*]} - 1)) -1 0); do
        eval "${on_exit_hooks[$i]}"
    done
}

add_on_exit()
{
    local n=${#on_exit_hooks[*]}
    on_exit_hooks[$n]="$*"
    if [[ $n -eq 0 ]]; then
        trap on_exit EXIT
    fi
}
