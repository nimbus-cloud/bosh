#!/bin/sh

# ubuntu trusty+ needs /etc/resolv.conf to be a symlink, so delete contents
# instead of removing the file to preserve the link
> /etc/resolv.conf
rm /etc/ssh/ssh_host*key*

DISTRIB_CODENAME=$(lsb_release --codename | cut -f2)
if [ $DISTRIB_CODENAME == "trusty" ]; then
  ifdown -a --no-loopback
  ifup -a --no-loopback
else
  ifdown -a --exclude=lo
  ifup -a --exclude=lo
fi

dpkg-reconfigure -fnoninteractive -pcritical openssh-server
dpkg-reconfigure -fnoninteractive sysstat

# We've seen problems on stemcell replacements when the mac has changed but the ip remains the same.
# The router caches the old mac address and doesn't forward new traffic to the new box until that
# box has sent some traffic via it. This call makes sure the router is aware of it on startup.

wget -O - -q -t 1 http://www.google.com > /dev/null 2>&1

