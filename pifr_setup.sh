#!/bin/bash
# PIFR puppet configuration script
# Based on setup instructions at https://docs.google.com/document/edit?id=1s2PG8GdWcovi9z8uCBiiHGBzALFQqt4noqLL4ADUbUw&hl=en
# This lives at https://github.com/scor/pifr_setup.

HOSTNAME=$(date +%Y%m%d)$RANDOM-pifr-mysql

# Architecture requirements validation.
if ! `uname -a | egrep '(amd64|x86_64)' 1>/dev/null 2>&1` ; then
  echo "A 64-bit architecture is required to run this script"
  exit
fi

echo "Setting up a PIFR client"
if ! test -d ~/.ssh ; then
  mkdir .ssh
  chmod 0600 .ssh
fi

echo "Are you willing to let this authorized_keys file allow root access to the listed people?"
cat authorized_keys
read -p "If you are willing, please type yes>" authkeys
if test "$authkeys" = "yes"; then
  cat authorized_keys >>~/.ssh/authorized_keys
fi

echo "Please paste your own ssh public key here, followed by ctrl-d"
cat >>~/.ssh/authorized_keys

chmod 600 ~/.ssh/authorized_keys
echo "Your key has been authorized for access. Please try ssh root@thishost."

read -p "What ethernet interface is primary? eth0 is default>" iface

if test "$iface" = ""; then
  iface=eth0
fi

ip_addr=$(ifconfig $iface | grep "inet addr:" | awk -F"[: ]*" '{print $4}')


echo $HOSTNAME >/etc/hostname
grep -v pifr-mysql /etc/hosts >/tmp/hosts.clean.txt
cp /tmp/hosts.clean.txt /etc/hosts
echo "$ip_addr $HOSTNAME" >>/etc/hosts
hostname $HOSTNAME

apt-get -qq -y update
apt-get -qq -y install rsync locales
cp sources.list /etc/apt/

# Set the locale so it doesn't while all the time
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
/usr/sbin/locale-gen

apt-get -qq -y update
apt-get -qq -y --force-yes install debian-archive-keyring
apt-get -qq -y update

# We force these here because puppet isn't so good at specifying particular packages.
apt-get -qq  -y --force-yes -t lenny-backports install puppet
apt-get -q -y --force-yes -t lenny-backports install git-core

# We may have changed the hostname of the machine if running this script
# again, so clean up puppet's keys
find /etc/puppet -type f | xargs rm

echo "Beginning puppet install"
puppetd --test --server puppet.damz.org 2>&1 | tee ~/puppetd.out

gzip -dc drupaltestbot.sql.gz | mysql drupaltestbot

echo "Puppet install complete. Please examine ~/puppetd.out"
echo "If you find failures like dependency failures, you may have to run puppetd --test --server puppet.damz.org again"
echo "Connect to and configure this instance config at admin/pifr"
