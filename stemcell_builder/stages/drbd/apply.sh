#!/usr/bin/env bash
#

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Disable interactive dpkg
debconf="debconf debconf/frontend select noninteractive"
run_in_chroot $chroot "echo ${debconf} | debconf-set-selections"

# Setup PPA for drbd 8.4
cat > $chroot/etc/apt/sources.list.d/ppa-drbd.list <<EOS
deb http://ppa.launchpad.net/icamargo/drbd/ubuntu $DISTRIB_CODENAME main 
deb-src http://ppa.launchpad.net/icamargo/drbd/ubuntu $DISTRIB_CODENAME main 
EOS
run_in_chroot $chroot "apt-get update"

# Install base debs needed by drbd
debs="drbd8-utils"

pkg_mgr install $debs

