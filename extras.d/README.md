# Extras Hooks

The `extras.d` directory contains project dispatch scripts that are called
at specific times by `stack.sh`, `unstack.sh` and `clean.sh`.  These hooks are
used to install, configure and start additional projects during a DevStack run
without any modifications to the base DevStack scripts.

When `stack.sh` reaches one of the hook points it sources the scripts in `extras.d`
that end with `.sh`.  To control the order that the scripts are sourced their
names start with a two digit sequence number.  DevStack reserves the sequence
numbers 00 through 09 and 90 through 99 for its own use.

The scripts are sourced at the beginning of each script that calls them. The
entire `stack.sh` variable space is available.  The scripts are
sourced with one or more arguments, the first of which defines the hook phase:

    source | stack | unstack | clean

    source: always called first in any of the scripts, used to set the
        initial defaults in a lib/* script or similar

    stack: called by stack.sh.  There are four possible values for
        the second arg to distinguish the phase stack.sh is in:

        arg 2:  pre-install | install | post-config | extra

    unstack: called by unstack.sh

    clean: called by clean.sh.  Remember, clean.sh also calls unstack.sh
        so that work need not be repeated.

The `stack` phase sub-phases are called from `stack.sh` in the following places:

    pre-install - After all system prerequisites have been installed but before any
        DevStack-specific services are installed (including database and rpc).

    install - After all OpenStack services have been installed and configured
        but before any OpenStack services have been started.  Changes to OpenStack
        service configurations should be done here.

    post-config - After OpenStack services have been initialized but still before
        they have been started. (This is probably mis-named, think of it as post-init.)

    extra - After everything is started.

