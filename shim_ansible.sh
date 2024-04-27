#!/bin/sh -e
#
# This shim will change the password for the "pi" user and run the ansible
# playbook that will install the software to transform the raspberry pi into
# a HestiaPi
#
# It expects the pi to be booted and SSH keys to already be set up with the
# private key located at ./id_25519
#
echo "Running $0"
export sshkey="id_25519-$RPI_OS_VERSION"
export host=127.0.0.1
export port=5022
if [ -z "$RPI_CPU" ]; then
	export RPI_CPU="arm1176"
fi
if [ -z "$RPI_OS_VERSION" ]; then
	echo "Error: \$RPI_OS_VERSION must be set before calling this script"
	exit 1
fi
if [ -z "$username" ]; then
	echo "Error: \$username must be set before calling this script"
	exit 1
fi
if [ -z "$QEMU" ]; then
	echo "Auto-detecting location of qemu-system-arm"
	export QEMU=$(which qemu-system-arm)
fi
echo "DEBUG: about to look for .img"
if [ -f *-rasp*-${RPI_OS_VERSION}-lite.img ]; then
	echo "We found the image file"
else
	echo "Image not found"
fi
echo "About to look at \$RPI_FS variable. Value = $RPI_FS"
if [ -z "$RPI_FS" ]; then
	echo "$0 Looking for *-rasp*-${RPI_OS_VERSION}-lite.img"
	export RPI_FS=`ls -t *-rasp*-${RPI_OS_VERSION}-lite.img | head -n 1`
fi

if [ -z "$PLAYBOOK" ]; then
	PLAYBOOK=hestiapi.yml
fi

cd ../ansible
chmod o-w .  # make sure we never run ansible from a world-writable directory
ansible-playbook --private-key ../qemu-rpi/$sshkey -i $host, \
	--extra-vars "$EXTRA_VARS" $EXTRA_ARGS \
	--ssh-extra-args "-p $port -o StrictHostKeyChecking=no" $PLAYBOOK
