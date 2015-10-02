#!/usr/bin/env bash

export BAT_DIRECTOR=10.76.247.230
export BAT_DNS_HOST=10.76.247.230
#export BAT_VCAP_PRIVATE_KEY=<private key file for vcap user $PWD/bats.pem>
export BAT_DEPLOYMENT_SPEC=$PWD/bats-config.yml
export BAT_INFRASTRUCTURE=vsphere
export BAT_NETWORKING=manual
export BAT_VCAP_PASSWORD=c1oudc0w
#export BAT_VCAP_PASSWORD=OY2WGb4SrdXtnCyNaWl
export BAT_STEMCELL=$PWD/tmp/bosh-stemcell-0000-vsphere-esxi-ubuntu-trusty-go_agent.tgz

#bundle exec rake bat:env
bundle exec rake bat