#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

run_in_chroot $chroot "
  echo \"vcap:${NIMBUS_PASSWORD}\" | chpasswd
  echo \"root:${NIMBUS_PASSWORD}\" | chpasswd
"
