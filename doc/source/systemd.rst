===========================
 Using Systemd in DevStack
===========================

By default DevStack is run with all the services as systemd unit
files. Systemd is now the default init system for nearly every Linux
distro, and systemd encodes and solves many of the problems related to
poorly running processes.

Why this instead of screen?
===========================

The screen model for DevStack was invented when the number of services
that a DevStack user was going to run was typically < 10. This made
screen hot keys to jump around very easy. However, the landscape has
changed (not all services are stoppable in screen as some are under
Apache, there are typically at least 20 items)

There is also a common developer workflow of changing code in more
than one service, and needing to restart a bunch of services for that
to take effect.

Unit Structure
==============

.. note::

   Originally we actually wanted to do this as user units, however
   there are issues with running this under non interactive
   shells. For now, we'll be running as system units. Some user unit
   code is left in place in case we can switch back later.

All DevStack user units are created as a part of the DevStack slice
given the name ``devstack@$servicename.service``. This makes it easy
to understand which services are part of the devstack run, and lets us
disable / stop them in a single command.

Manipulating Units
==================

Assuming the unit ``n-cpu`` to make the examples more clear.

Enable a unit (allows it to be started)::

  sudo systemctl enable devstack@n-cpu.service

Disable a unit::

  sudo systemctl disable devstack@n-cpu.service

Start a unit::

  sudo systemctl start devstack@n-cpu.service

Stop a unit::

  sudo systemctl stop devstack@n-cpu.service

Restart a unit::

  sudo systemctl restart devstack@n-cpu.service

See status of a unit::

  sudo systemctl status devstack@n-cpu.service

Operating on more than one unit at a time
-----------------------------------------

Systemd supports wildcarding for unit operations. To restart every
service in devstack you can do that following::

  sudo systemctl restart devstack@*

Or to see the status of all Nova processes you can do::

  sudo systemctl status devstack@n-*

We'll eventually make the unit names a bit more meaningful so that
it's easier to understand what you are restarting.

.. _journalctl-examples:

Querying Logs
=============

One of the other major things that comes with systemd is journald, a
consolidated way to access logs (including querying through structured
metadata). This is accessed by the user via ``journalctl`` command.


Logs can be accessed through ``journalctl``. journalctl has powerful
query facilities. We'll start with some common options.

Follow logs for a specific service::

  journalctl -f --unit devstack@n-cpu.service

Following logs for multiple services simultaneously::

  journalctl -f --unit devstack@n-cpu.service --unit
  devstack@n-cond.service

or you can even do wild cards to follow all the nova services::

  journalctl -f --unit devstack@n-*

Use higher precision time stamps::

  journalctl -f -o short-precise --unit devstack@n-cpu.service

By default, journalctl strips out "unprintable" characters, including
ASCII color codes. To keep the color codes (which can be interpreted by
an appropriate terminal/pager - e.g. ``less``, the default)::

  journalctl -a --unit devstack@n-cpu.service

When outputting to the terminal using the default pager, long lines
appear to be truncated, but horizontal scrolling is supported via the
left/right arrow keys.

See ``man 1 journalctl`` for more.

Known Issues
============

Be careful about systemd python libraries. There are 3 of them on
pypi, and they are all very different. They unfortunately all install
into the ``systemd`` namespace, which can cause some issues.

- ``systemd-python`` - this is the upstream maintained library, it has
  a version number like systemd itself (currently ``234``). This is
  the one you want.
- ``systemd`` - a python 3 only library, not what you want.
- ``python-systemd`` - another library you don't want. Installing it
  on a system will break ansible's ability to run.


If we were using user units, the ``[Service]`` - ``Group=`` parameter
doesn't seem to work with user units, even though the documentation
says that it should. This means that we will need to do an explicit
``/usr/bin/sg``. This has the downside of making the SYSLOG_IDENTIFIER
be ``sg``. We can explicitly set that with ``SyslogIdentifier=``, but
it's really unfortunate that we're going to need this work
around. This is currently not a problem because we're only using
system units.

Future Work
===========

user units
----------

It would be great if we could do services as user units, so that there
is a clear separation of code being run as not root, to ensure running
as root never accidentally gets baked in as an assumption to
services. However, user units interact poorly with devstack-gate and
the way that commands are run as users with ansible and su.

Maybe someday we can figure that out.

References
==========

- Arch Linux Wiki - https://wiki.archlinux.org/index.php/Systemd/User
- Python interface to journald -
  https://www.freedesktop.org/software/systemd/python-systemd/journal.html
- Systemd documentation on service files -
  https://www.freedesktop.org/software/systemd/man/systemd.service.html
- Systemd documentation on exec (can be used to impact service runs) -
  https://www.freedesktop.org/software/systemd/man/systemd.exec.html
