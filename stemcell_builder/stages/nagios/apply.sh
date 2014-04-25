#!/usr/bin/env bash
#

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash



# Disable interactive dpkg
debconf="debconf debconf/frontend select noninteractive"
run_in_chroot $chroot "echo ${debconf} | debconf-set-selections"

# Install base debs needed by munin
debs="nagios3"
# libdbd-pg-perl needed by postgresql

pkg_mgr install $debs

# now make sure nagios doesn't startup 
run_in_chroot $chroot "update-rc.d apache2 disable"
run_in_chroot $chroot "update-rc.d nagios3 disable"


