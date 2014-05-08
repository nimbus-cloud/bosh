#!/usr/bin/env bash
#

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/drbd-8.4.4.tar.gz $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
cd src
tar zxvf drbd-8.4.4.tar.gz
cd drbd-8.4.4
./configure --prefix=/ --with-km
make KDIR=/usr/src/linux-headers-3.0.0-32-virtual && make install
"
