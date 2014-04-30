#!/bin/bash

# pid number for temp directory
BASH_PID=$$
# temporary directory number
TMP_DIR="version-updater-tmp.$$"
#date of the stemcell
STEMCELL_DATE="`date +%y%m%d%H%M`"

ORIGINAL_STEMCELL=`ls -tr tmp/bosh-stemcell-????-*.tgz | tail -1`
TMP_ORIGINAL_STEMCELL=$ORIGINAL_STEMCELL

if [ -z $1 ];
then
	echo "usage:"
	echo "  $0 <path/to/stemcell>"
	echo "to update the specific stemcell image"
	echo
	echo "  $0"
	echo "to update the last built stemcell image"
else
	TMP_ORIGINAL_STEMCELL=$1
fi

NEW_STEMCELL_NAME=`basename $TMP_ORIGINAL_STEMCELL | sed "s/-\([0-9]*\)-/-\1.$STEMCELL_DATE-/g"`
EXISTING_STEMCELL_DIR=`dirname $TMP_ORIGINAL_STEMCELL`

echo "Found stemcell to update: $TMP_ORIGINAL_STEMCELL"

# make the directory
mkdir -p $TMP_DIR

#untar the stemcell file
echo "untarring..."
tar xf $TMP_ORIGINAL_STEMCELL -C $TMP_DIR

pushd $TMP_DIR >> /dev/null
echo "updating stemcell version..."
cat stemcell.MF | sed "s/version\:\ '\([0-9]*\)'/version\:\ '\1.$STEMCELL_DATE'/g" > stemcell.updated.MF
mv stemcell.updated.MF stemcell.MF

echo "tarring..."
tar czf $NEW_STEMCELL_NAME *
popd >> /dev/null

mv $TMP_DIR/$NEW_STEMCELL_NAME $EXISTING_STEMCELL_DIR

echo "cleaning up..."
echo "build new stemcell: $NEW_STEMCELL_NAME"
rm -rf $TMP_DIR
