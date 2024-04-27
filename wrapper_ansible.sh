#!/bin/sh -e
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
echo "$0 Looking for *-rasp*-${RPI_OS_VERSION%%[0-9]*}-*lite.img"
export RPI_FS=`ls -t *-rasp*-${RPI_OS_VERSION%%[0-9]*}-*lite.img | head -n 1`

# If you've ever used this script before, you'll have an old entry in your
# known hosts, we need to clean that up.  If we don't have the expected files,
# we need to create them to avoid ssh-keygen to error out.
echo "Setting up SSH keys"
mkdir -p $HOME/.ssh           # make sure the directory exists
chmod 0700 $HOME/.ssh         # make sure the permissions are right
touch $HOME/.ssh/known_hosts  # make sure the file exists
echo "Cleaning out any old known_hosts entries..."
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "[127.0.0.1]:5022"
echo "Pushing keys over to the VM..."
../push_keys.ex
echo "Done pushing keys over to the VM."
# Sometimes the qemu process takes bloody forever to go away after the VM says
# it is shut down!
sleep 60

echo "Starting the VM"
../boot_vm.ex shim_ansible.sh
# boot_vm.ex will wait for the login prompt than then run
# the target scipt (on the host).  The script is expected
# to remote into the pi and do its thing.  This enables
# that same script to be used on both physical and virtual
# devices.
