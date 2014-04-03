#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

pkg_mgr install open-vm-tools

# replace vmxnet3 from included kernel
mkdir -p $chroot/tmp
cp $assets_dir/vmware-tools-vmxnet3-modules-source_1.0.36.0-2_amd64.deb $chroot/tmp
cp $assets_dir/vmware-tools-install.sh $chroot/tmp

run_in_chroot $chroot "
dpkg -i /tmp/vmware-tools-vmxnet3-modules-source_1.0.36.0-2_amd64.deb
rm -f /tmp/*.deb
/tmp/vmware-tools-install.sh
"
