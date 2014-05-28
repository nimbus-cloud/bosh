#!/usr/bin/env bash
#

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash



# Disable interactive dpkg
debconf="debconf debconf/frontend select noninteractive"
run_in_chroot $chroot "echo ${debconf} | debconf-set-selections"

# Install base debs needed by munin
debs="nagios-nrpe-server nagios-plugins"
# libdbd-pg-perl needed by postgresql

pkg_mgr install $debs

# now make sure nagios doesn't startup 
#run_in_chroot $chroot "update-rc.d -f apache2 disable"


