#!/usr/bin/env bash

# **build_docs.sh** - Build the gh-pages docs for DevStack
#
# - Install shocco if not found on PATH and INSTALL_SHOCCO is set
# - Clone MASTER_REPO branch MASTER_BRANCH
# - Re-creates ``docs/html`` directory from existing repo + new generated script docs

# Usage:
## build_docs.sh [-o <out-dir>] [-g] [master|<repo> [<branch>]]
## <repo>           The DevStack repository to clone (default is DevStack github repo)
##                  If a repo is not supplied use the current directory
##                  (assumed to be a DevStack checkout) as the source.
## <branch>         The DevStack branch to check out (default is master; ignored if
##                  repo is not specified)
## .                Use the current repo and branch (do not use with -p to
##                  prevent stray files in the workspace being added tot he docs)
## -o <out-dir>     Write the static HTML output to <out-dir>
##                  (Note that <out-dir> will be deleted and re-created to ensure it is clean)
## -g               Update the old gh-pages repo  (set PUSH=1 to actualy push up to RCB)

# Defaults
# --------

# Source repo/branch for DevStack
MASTER_REPO=${MASTER_REPO:-git://git.openstack.org/openstack-dev/devstack}
MASTER_BRANCH=${MASTER_BRANCH:-master}

# http://devstack.org is a GitHub gh-pages site in the https://github.com/cloudbuilders/devtack.git repo
GH_PAGES_REPO=git@github.com:cloudbuilders/devstack.git

DOCS_SOURCE=docs/source
HTML_BUILD=docs/html

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
        make || exit
        cd ..
    fi
    SHOCCO=$TOP_DIR/shocco/shocco
fi

# Process command-line args
while getopts go: c; do
    case $c in
        g)  GH_UPDATE=1
            ;;
        o)  HTML_BUILD=$OPTARG
            ;;
    esac
done
shift `expr $OPTIND - 1`


if [[ -n "$1" ]]; then
    master="master"
    if [[ "${master/#$1}" != "master" ]]; then
        # Partial match on "master"
        REPO=$MASTER_REPO
    else
        REPO=$1
    fi
    REPO_BRANCH=${2:-$MASTER_BRANCH}
fi

# Check out a specific DevStack branch
if [[ -n $REPO ]]; then
    # Make a workspace
    TMP_ROOT=$(mktemp -d work-docs-XXXX)
    echo "Building docs in $TMP_ROOT"
    cd $TMP_ROOT

    # Get the master branch
    git clone $REPO devstack
    cd devstack
    if [[ -n "$REPO_BRANCH" ]]; then
        git checkout $REPO_BRANCH
    fi
fi

# Assumption is we are now in the DevStack workspace to be processed

# Processing
# ----------

# Clean up build dir
rm -rf $HTML_BUILD
mkdir -p $HTML_BUILD

# Get fully qualified dirs
FQ_DOCS_SOURCE=$(cd $DOCS_SOURCE && pwd)
FQ_HTML_BUILD=$(cd $HTML_BUILD && pwd)

# Get repo static
cp -pr $FQ_DOCS_SOURCE/* $FQ_HTML_BUILD

# Build list of scripts to process
FILES=""
for f in $(find . -name .git -prune -o \( -type f -name \*.sh -not -path \*shocco/\* -print \)); do
    echo $f
    FILES+="$f "
    mkdir -p $FQ_HTML_BUILD/`dirname $f`;
    $SHOCCO $f > $FQ_HTML_BUILD/$f.html
done
for f in $(find functions functions-common lib samples -type f -name \*); do
    echo $f
    FILES+="$f "
    mkdir -p $FQ_HTML_BUILD/`dirname $f`;
    $SHOCCO $f > $FQ_HTML_BUILD/$f.html
done
echo "$FILES" >docs/files

if [[ -n $GH_UPDATE ]]; then
    GH_ROOT=$(mktemp -d work-gh-XXXX)
    cd $GH_ROOT

    # Pull the latest docs branch from devstack.org repo
    git clone -b gh-pages $GH_PAGES_REPO gh-docs

    # Get the generated files
    cp -pr $FQ_HTML_BUILD/* gh-docs

    # Collect the new generated pages
    (cd gh-docs; find . -name \*.html -print0 | xargs -0 git add)

    # Push our changes back up to the docs branch
    if ! git diff-index HEAD --quiet; then
        git commit -a -m "Update script docs"
        if [[ -n $PUSH ]]; then
            git push
        fi
    fi
fi

# Clean up or report the temp workspace
if [[ -n REPO && -n $PUSH_REPO ]]; then
    echo rm -rf $TMP_ROOT
else
    if [[ -z "$TMP_ROOT" ]]; then
        TMP_ROOT="$(pwd)"
    fi
    echo "Built docs in $HTML_BUILD"
fi
