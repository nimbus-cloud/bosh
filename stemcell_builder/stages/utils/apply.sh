#!/usr/bin/env bash
#

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash



# Disable interactive dpkg
debconf="debconf debconf/frontend select noninteractive"
run_in_chroot $chroot "echo ${debconf} | debconf-set-selections"

# Install utility debs 
debs="nano vim"

pkg_mgr install $debs

