#!/bin/bash

PKGS=" git emacs-nox screen redhat-lsb python-pip telnet bash-completion "
EPEL_RPM_URL="http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-5.noarch.rpm"
REPOFORGE_RPM_URL="http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.2-2.el6.rf.x86_64.rpm"
RPM="sudo rpm"
YUM="sudo yum "

#
# Setup EPEL
#
$RPM -Uhv $EPEL_RPM_URL
$RPM -Uhv $REPOFORGE_RPM_URL

#
# Update the systems
#
$YUM -y upgrade

#
# Install your custom packages and environment
#
$YUM -y install $PKGS

(
cat <<EOF
if [ -f /etc/bashrc ]; then
   . /etc/bashrc   # --> Read /etc/bashrc, if present.
fi
if [ -f /etc/bash.bashrc ]; then
   . /etc/bash.bashrc   # --> Read /etc/bash.bashrc, if present.
fi

if [ -f $HOME/.bashrc ]; then
   . $HOME/.bashrc   # --> Read /etc/bash.bashrc, if present.
fi

export EDITOR=emacs
export PROMPT="\u@\h \W> "
export PS1=$PROMPT

#TTY=`/usr/bin/tty`
#if [ "$TTY" != "not a tty" -a "$TERM" != "screen" -a "$SHLVL" -eq 1 -a -n "$SSH_CLIENT" ]; then
#    screen -t `hostname` -x -RR remote
#fi

EOF
) >> ~/.bash_profile

(
cat <<EOF
  startup_message off                   # default: on
  defscrollback 8192                    # default: 100
  vbell off
  nethack on                            # default: off
  crlf off                              # default: off
  caption always "%{= kw} %H | %{kc}%?%-w%?%{kY}%n*%f %t%?(%u)%?%{= kc}%?%+w%? %=|%{kW} %l %{kw}| %{kc}%{-b}%D, %m/%d/%Y |%{kW}%{+b}%c:%s %{wk}" 
  termcapinfo xterm* 'hs:ts=\E]0;:fs=\007:ds=\E]0;\007'
  defhstatus "screen ^E (^Et) | $USER@^EH"
  hardstatus off
EOF
) > ~/.screenrc



#
# Setup the ephemeral storage as the target for openstack
#
sudo mkdir -p /media/ephemeral0/stack
sudo ln -s /media/ephemeral0/stack /opt/stack
