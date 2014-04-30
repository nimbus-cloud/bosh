#!/usr/bin/env bash
#

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash



# Disable interactive dpkg
debconf="debconf debconf/frontend select noninteractive"
run_in_chroot $chroot "echo ${debconf} | debconf-set-selections"

# Install base debs needed by munin
debs="munin munin-node libdbd-pg-perl"
# libdbd-pg-perl needed by postgresql

pkg_mgr install $debs

# remove the auto-startup of munin
run_in_chroot $chroot "sudo update-rc.d -f munin-node remove"

# now make the directory with the correct permissions
run_in_chroot $chroot "mkdir -p /var/run/munin"
run_in_chroot $chroot "chown root:root /var/run/munin"
run_in_chroot $chroot "chmod 644 /var/run/munin"

# remove all of the currently linked in munin plugins
run_in_chroot $chroot "rm /etc/munin/plugins/*"
run_in_chroot $chroot "rm /etc/munin/plugin-conf.d/*"

# remove the configuration for munin
run_in_chroot $chroot "rm /etc/munin/munin-node.conf"
run_in_chroot $chroot "rm /etc/munin/munin.conf"

# remove the munin master cron entry
run_in_chroot $chroot "rm /etc/cron.d/munin"
run_in_chroot $chroot "rm /etc/cron.d/munin-node"

# change the temp directory
run_in_chroot $chroot "chmod a+rwx /tmp"