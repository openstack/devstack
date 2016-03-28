#!/usr/bin/env bash

# **build_docs.sh** - Build the docs for DevStack
#
# - Install shocco if not found on ``PATH`` and ``INSTALL_SHOCCO`` is set
# - Clone ``MASTER_REPO`` branch ``MASTER_BRANCH``
# - Re-creates ``doc/build/html`` directory from existing repo + new generated script docs

# Usage:
## build_docs.sh [-o <out-dir>]
## -o <out-dir>     Write the static HTML output to <out-dir>
##                  (Note that <out-dir> will be deleted and re-created to ensure it is clean)

# Defaults
# --------

HTML_BUILD=doc/build/html

# Keep track of the DevStack directory
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
while getopts o: c; do
    case $c in
        o)  HTML_BUILD=$OPTARG
            ;;
    esac
done
shift `expr $OPTIND - 1`


# Processing
# ----------

# Ensure build dir exists
mkdir -p $HTML_BUILD

# Get fully qualified dirs
FQ_HTML_BUILD=$(cd $HTML_BUILD && pwd)

# Insert automated bits
GLOG=$(mktemp gitlogXXXX)
echo "<ul>" >$GLOG
git log \
    --pretty=format:'            <li>%s - <em>Commit <a href="https://review.openstack.org/#q,%h,n,z">%h</a> %cd</em></li>' \
    --date=short \
    --since '6 months ago' | grep -v Merge >>$GLOG
echo "</ul>" >>$GLOG
sed -i~ -e $"/^.*%GIT_LOG%.*$/r $GLOG" -e $"/^.*%GIT_LOG%.*$/s/^.*%GIT_LOG%.*$//" $FQ_HTML_BUILD/changes.html
rm -f $GLOG

# Build list of scripts to process
FILES=""
for f in $(find . \( -name .git -o -name .tox \) -prune -o \( -type f -name \*.sh -not -path \*shocco/\* -print \)); do
    echo $f
    FILES+="$f "
    mkdir -p $FQ_HTML_BUILD/`dirname $f`;
    $SHOCCO $f > $FQ_HTML_BUILD/$f.html
done
for f in $(find functions functions-common inc lib pkg samples -type f -name \* ! -name *.md ! -name *.conf); do
    echo $f
    FILES+="$f "
    mkdir -p $FQ_HTML_BUILD/`dirname $f`;
    $SHOCCO $f > $FQ_HTML_BUILD/$f.html
done
echo "$FILES" >doc/files

# Clean up or report the temp workspace
if [[ -n REPO && -n $PUSH_REPO ]]; then
    echo rm -rf $TMP_ROOT
else
    if [[ -z "$TMP_ROOT" ]]; then
        TMP_ROOT="$(pwd)"
    fi
    echo "Built docs in $HTML_BUILD"
fi
