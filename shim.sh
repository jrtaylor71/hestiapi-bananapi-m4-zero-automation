#!/bin/sh -e
#
# This shim will change the password for the "pi" user, copy over the script to
# install the software to transform the raspberry pi into a HestiaPi, and then
# SSH in and run that script.
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

# We only want to change the password if it's needed. This is an optimization
# for reducing issues with the CI jobs getting frozen at this step sometimes.
if [ -z "$SCRIPT" -o "$SCRIPT" = "hestiapi.sh" ]; then
	echo "Changing password of $username..."
	ssh -o "StrictHostKeyChecking no" -i $sshkey -p $port $username@$host 'printf "hestia\nhestia\n" | sudo passwd pi'
	echo "Password has been changed"
fi

if [ -z "$SCRIPT" ]; then
	SCRIPT=hestiapi.sh
fi
echo "Copying over $SCRIPT"
scp -o StrictHostKeyChecking=no -i $sshkey -P $port "../$SCRIPT" $username@$host:
echo "Running $SCRIPT"
ssh -o StrictHostKeyChecking=no -i $sshkey -p $port $username@$host "./$SCRIPT"
echo "Done running $SCRIPT"
