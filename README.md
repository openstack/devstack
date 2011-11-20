Tool to quickly deploy openstack dev environments.

# Goals

* To quickly build dev openstack environments in clean oneiric environments
* To describe working configurations of openstack (which code branches work together?  what do config files look like for those branches?)
* To make it easier for developers to dive into openstack so that they can productively contribute without having to understand every part of the system at once
* To make it easy to prototype cross-project features

Read more at http://devstack.org (built from the gh-pages branch)

Be sure to carefully read these scripts before you run them as they install software and may alter your networking configuration.

# To start a dev cloud on your local machine (installing on a dedicated vm is safer!):

    ./stack.sh

If working correctly, you should be able to access openstack endpoints, like:

* Horizon: http://myhost/
* Keystone: http://myhost:5000/v2.0/

# Customizing

You can tweak environment variables by creating file name 'localrc' should you need to override defaults.  It is likely that you will need to do this to tweak your networking configuration should you need to access your cloud from a different host.

# Todo

* Add python-novaclient cli support
* syslog
* Add volume support
* Add quantum support

# Future

* idea: move from screen to tmux?
* idea: create a live-cd / vmware preview image using this?
