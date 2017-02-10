#!/bin/bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

echo "Nimbus password stage config, env:"

env

if [ -z "${NIMBUS_PASSWORD:-}" ]; then
  echo "Environment variable NIMBUS_PASSWORD is required for Nimbus stemcell."
  exit 1
else
  echo "PERSISTING ENVIRONMENT TO ${settings_file}"
  persist_value NIMBUS_PASSWORD
fi

