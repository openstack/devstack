# DevStack Makefile of Sanity

# Interesting targets:
# ds-remote - Create a Git remote for use by ds-push and ds-pull targets
#             DS_REMOTE_URL must be set on the command line
#
# ds-push - Merge a list of branches taken from .ds-test and push them
#           to the ds-remote repo in ds-test branch
#
# ds-pull - Pull the remote ds-test branch into a fresh local branch
#
# refresh - Performs a sequence of unstack, refresh and stack

# Duplicated from stackrc for now
DEST=/opt/stack

all:
	@echo "This just saved you from a terrible mistake!"

# Do Some Work
stack:
	./stack.sh

unstack:
	./unstack.sh

docs:
	tox -edocs

# Just run the shocco source formatting build
docs-build:
	INSTALL_SHOCCO=True tools/build_docs.sh

# Just run the Sphinx docs build
docs-rst:
	python setup.py build_sphinx

# Run the bashate test
bashate:
	tox -ebashate

# Run the function tests
test:
	tests/test_ini_config.sh
	tests/test_meta_config.sh
	tests/test_ip.sh
	tests/test_refs.sh

# Spiff up the place a bit
clean:
	./clean.sh
	rm -rf accrc doc/build test*-e *.egg-info

# Clean out the cache too
realclean: clean
	rm -rf files/cirros*.tar.gz files/Fedora*.qcow2

# Repo stuffs

pull:
	git pull


# These repo targets are used to maintain a branch in a remote repo that
# consists of one or more local branches merged and pushed to the remote.
# This is most useful for iterative testing on multiple or remote servers
# while keeping the working repo local.
#
# It requires:
# * a remote pointing to a remote repo, often GitHub is used for this
# * a branch name to be used on the remote
# * a local file containing the list of local branches to be merged into
#   the remote branch

GIT_REMOTE_NAME=ds-test
GIT_REMOTE_BRANCH=ds-test

# Push the current branch to a remote named ds-test
ds-push:
	git checkout master
	git branch -D $(GIT_REMOTE_BRANCH) || true
	git checkout -b $(GIT_REMOTE_BRANCH)
	for i in $(shell cat .$(GIT_REMOTE_BRANCH) | grep -v "^#" | grep "[^ ]"); do \
	  git merge --no-edit $$i; \
	done
	git push -f $(GIT_REMOTE_NAME) HEAD:$(GIT_REMOTE_BRANCH)

# Pull the ds-test branch
ds-pull:
	git checkout master
	git branch -D $(GIT_REMOTE_BRANCH) || true
	git pull $(GIT_REMOTE_NAME) $(GIT_REMOTE_BRANCH)
	git checkout $(GIT_REMOTE_BRANCH)

# Add the remote - set DS_REMOTE_URL=htps://example.com/ on the command line
ds-remote:
	git remote add $(GIT_REMOTE_NAME) $(DS_REMOTE_URL)

# Refresh the current DevStack checkout nd re-initialize
refresh: unstack ds-pull stack
