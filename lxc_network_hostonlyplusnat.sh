#!/bin/bash

# Print some usage info
function usage {
  echo "Usage: $0 [OPTION] [host_ip]"
  echo "Set up temporary networking for LXC"
  echo ""
  echo "  -n, --dry-run            Just print the commands that would execute."
  echo "  -h, --help               Print this usage message."
  echo ""
  exit
}

# Allow passing the ip address on the command line.
function process_option {
  case "$1" in
    -h|--help) usage;;
    -n|--dry-run) dry_run=1;;
    *) host_ip="$1"
  esac
}

# Set up some defaults
host_ip=
dry_run=0
bridge=br0
DRIER=

# Process the args
for arg in "$@"; do
  process_option $arg
done

if [ $dry_run ]; then
  DRIER=echo
fi

if [ "$UID" -ne "0" ]; then
  echo "This script must be run with root privileges."
  exit 1
fi

# Check for bridge-utils.
BRCTL=`which brctl`
if [ ! -x "$BRCTL" ]; then
  echo "This script requires you to install bridge-utils."
  echo "Try: sudo apt-get install bridge-utils."
  exit 1
fi

# Scare off the nubs.
echo "====================================================="
echo
echo "WARNING"
echo
echo "This script will modify your current network setup,"
echo "this can be a scary thing and it is recommended that"
echo "you have something equivalent to physical access to"
echo "this machine before continuing in case your network"
echo "gets all funky."
echo
echo "If you don't want to continue, hit CTRL-C now."

if [ -z "$host_ip" ];
then
  echo "Otherwise, please type in your host's ip address and"
  echo "hit enter."
  echo
  echo "====================================================="
  read host_ip
else
  echo "Otherwise hit enter."
  echo
  echo "====================================================="
  read accept
fi


# Add a bridge interface, this will choke if there is already
# a bridge named $bridge
$DRIER $BRCTL addbr $bridge
$DRIER ip addr add 192.168.1.1/24 dev $bridge
if [ $dry_run ]; then
  echo "echo 1 > /proc/sys/net/ipv4/ip_forward"
else
  echo 1 > /proc/sys/net/ipv4/ip_forward
fi
$DRIER ifconfig $bridge up

# Set up the NAT for the instances
$DRIER iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -j SNAT --to-source $host_ip
$DRIER iptables -I FORWARD -s 192.168.1.0/24 -j ACCEPT

