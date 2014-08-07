#!/usr/bin/env bash
#

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

mkdir -p $chroot/$bosh_dir/src
cp -r $dir/assets/drbd-8.4.5.tar.gz $chroot/$bosh_dir/src
cp -r $dir/assets/drbd-utils-8.9.0.tar.gz $chroot/$bosh_dir/src

pkg_mgr install lvm2

run_in_bosh_chroot $chroot '
cd src
tar zxvf drbd-8.4.5.tar.gz
cd drbd-8.4.5
make KDIR=/lib/modules/3.13.0-32-generic/build && make install
depmod -a 3.13.0-32-generic
cd ..
tar zxvf drbd-utils-8.9.0.tar.gz
cd drbd-utils-8.9.0
./configure --prefix=/
make && make install
#cp scripts/drbd.conf /etc/drbd.conf
#mkdir /etc/drbd.d
'

cp -v $dir/assets/global_common.conf $chroot/etc/drbd.d/
