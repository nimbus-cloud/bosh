#!/usr/bin/env bash
#

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash



# Disable interactive dpkg
debconf="debconf debconf/frontend select noninteractive"

# make the directory
run_in_chroot $chroot "sudo mkdir /usr/share/ca-certificates/extra"
# copy the certificate
cp $assets_dir/bskyb-dev-ca.crt $chroot/usr/share/ca-certificates/extra/bskyb-dev-ca.crt
# reconfigure
run_in_chroot $chroot "sudo dpkg-reconfigure -f noninteractive ca-certificates"

