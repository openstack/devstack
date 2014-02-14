#!/usr/bin/env bash

# **build_docs.sh** - Build the gh-pages docs for DevStack
#
# - Install shocco if not found on PATH
# - Clone MASTER_REPO branch MASTER_BRANCH
# - Re-creates ``docs`` directory from existing repo + new generated script docs

# Usage:
## build_docs.sh [[-b branch] [-p] repo] | .
## -b branch        The DevStack branch to check out (default is master; ignored if
##                  repo is not specified)
## -p               Push the resulting docs tree to the source repo; fatal error if
##                  repo is not specified
## repo             The DevStack repository to clone (default is DevStack github repo)
##                  If a repo is not supplied use the current directory
##                  (assumed to be a DevStack checkout) as the source.
## .                Use the current repo and branch (do not use with -p to
##                  prevent stray files in the workspace being added tot he docs)

# Defaults
# --------

# Source repo/branch for DevStack
MASTER_REPO=${MASTER_REPO:-https://github.com/openstack-dev/devstack.git}
MASTER_BRANCH=${MASTER_BRANCH:-master}

# http://devstack.org is a GitHub gh-pages site in the https://github.com/cloudbuilders/devtack.git repo
GH_PAGES_REPO=git@github.com:cloudbuilders/devstack.git

# Keep track of the devstack directory
TOP_DIR=$(cd $(dirname "$0")/.. && pwd)

# Uses this shocco branch: https://github.com/dtroyer/shocco/tree/rst_support
SHOCCO=${SHOCCO:-shocco}
if ! which shocco; then
    if [[ ! -x $TOP_DIR/shocco/shocco ]]; then
        if [[ -z "$INSTALL_SHOCCO" ]]; then
            echo "shocco not found in \$PATH, please set environment variable SHOCCO"
            exit 1
        fi
        echo "Installing local copy of shocco"
        if ! which pygmentize; then
            sudo pip install Pygments
        fi
        if ! which rst2html.py; then
            sudo pip install docutils
        fi
        git clone -b rst_support https://github.com/dtroyer/shocco shocco
        cd shocco
        ./configure
        make
        cd ..
    fi
    SHOCCO=$TOP_DIR/shocco/shocco
fi

# Process command-line args
while getopts b:p c; do
    case $c in
        b)  MASTER_BRANCH=$OPTARG
            ;;
        p)  PUSH_REPO=1
            ;;
    esac
done
shift `expr $OPTIND - 1`

# Sanity check the args
if [[ "$1" == "." ]]; then
    REPO=""
    if [[ -n $PUSH_REPO ]]; then
        echo "Push not allowed from an active workspace"
        unset PUSH_REPO
    fi
else
    if [[ -z "$1" ]]; then
        REPO=$MASTER_REPO
    else
        REPO=$1
    fi
fi

# Check out a specific DevStack branch
if [[ -n $REPO ]]; then
    # Make a workspace
    TMP_ROOT=$(mktemp -d devstack-docs-XXXX)
    echo "Building docs in $TMP_ROOT"
    cd $TMP_ROOT

    # Get the master branch
    git clone $REPO devstack
    cd devstack
    git checkout $MASTER_BRANCH
fi

# Processing
# ----------

# Assumption is we are now in the DevStack repo workspace to be processed

# Pull the latest docs branch from devstack.org repo
if ! [ -d docs ]; then
    git clone -b gh-pages $GH_PAGES_REPO docs
fi

# Build list of scripts to process
FILES=""
for f in $(find . -name .git -prune -o \( -type f -name \*.sh -not -path \*shocco/\* -print \)); do
    echo $f
    FILES+="$f "
    mkdir -p docs/`dirname $f`;
    $SHOCCO $f > docs/$f.html
done
for f in $(find functions lib samples -type f -name \*); do
    echo $f
    FILES+="$f "
    mkdir -p docs/`dirname $f`;
    $SHOCCO $f > docs/$f.html
done
echo "$FILES" >docs-files

# Switch to the gh_pages repo
cd docs

# Collect the new generated pages
find . -name \*.html -print0 | xargs -0 git add

# Push our changes back up to the docs branch
if ! git diff-index HEAD --quiet; then
    git commit -a -m "Update script docs"
    if [[ -n $PUSH ]]; then
        git push
    fi
fi

# Clean up or report the temp workspace
if [[ -n REPO && -n $PUSH_REPO ]]; then
    rm -rf $TMP_ROOT
else
    if [[ -z "$TMP_ROOT" ]]; then
        TMP_ROOT="$(pwd)"
    fi
    echo "Built docs in $TMP_ROOT"
fi
