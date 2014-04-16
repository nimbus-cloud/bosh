#!/bin/bash

# 
# Build the latest, most up to date stemcell for targeted platforms
# 
# 
# 

PLATFORMS=("warden" "aws" "openstack" "vsphere" "vcloud")
OSES=("ubuntu" "centos")


function usage {
	echo "usage:"
	echo
	echo "  $0 <platform> <os> [candidate_build_number]"
	echo
	echo "where:"
	echo "  <platform> is one of warden|aws|openstack|vsphere|vcloud"
	echo "        <os> is one of ubuntu|centos"
	echo " and"
	echo "  [candidate_build_number] is optionally the targetted build number"
	echo
	exit
}

FOUND_PLATFORM=0

if test -z "$1"
then
	usage
else
	# test if it is a valid value
	for i in "${PLATFORMS[@]}"
	do
		if [[ $i = $1 ]]
		then
			export FOUND_PLATFORM=1
		fi
	done
fi

FOUND_OS=0

if test -z "$2"
then
	usage
else
	# test if it is a valid value
	for i in "${OSES[@]}"
	do
		if [[ $i = $2 ]]
		then
			export FOUND_OS=1
		fi
	done
fi

if [[ $FOUND_PLATFORM = 0 ]]
then
	echo
	echo "FATAL: invalid platform found '$1'"
	echo
	echo "Should be one of"
	for i in "${PLATFORMS[@]}"
	do
		echo "  $i"
	done
	echo
	usage
fi

if [[ $FOUND_OS = 0 ]]
then
	echo
	echo "FATAL: invalid os found '$2'"
	echo
	echo "Should be one of"
	for i in "${OSES[@]}"
	do
		echo "  $i"
	done
	echo
	usage
fi

# at this point we should be ready to build...
# just need to check 

CANDIDATE_BUILD_NUMBER=0

if test -z "$3"
then
	export CANDIDATE_BUILD_NUMBER=`curl -s http://bosh_artifacts.cfapps.io/ | grep "<strong>" | head -1 | sed s/[^0-9]*//g`
else
	echo "Over-riding candidate build number with: '$3'"
	export CANDIDATE_BUILD_NUMBER=$3
fi



PLATFORM=$1
OS=$1

CANDIDATE_BUILD_NUMBER=$CANDIDATE_BUILD_NUMBER http_proxy=http://localhost:3142/ bundle exec rake stemcell:build[$1,$2,ruby,ci4-bosh-os-images-ubuntu,`curl -s https://s3.amazonaws.com/ci4-bosh-os-images-$2/ | awk -F "Key>" '{print $2}' | cut -d "<" -f1 | tr -d '\r\n '`]