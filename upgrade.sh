#!/bin/sh -e
# This will SSH into the VM and upgrade it and then shut it down
export sshkey="id_25519-$RPI_OS_VERSION"
export host=127.0.0.1
export port=5022
export username="pi"

echo "DEBUG: lets take a look at sources.list..."
ssh -o "StrictHostKeyChecking no" -i $sshkey -p $port $username@$host 'cat /etc/apt/sources.list'
echo "DEBUG: lets take a look at other apt sources..."
ssh -o "StrictHostKeyChecking no" -i $sshkey -p $port $username@$host 'cat /etc/apt/sources.list.d/*'
echo "DEBUG: done looking at apt sources."

if [ $RPI_OS_VERSION = "buster" ]; then
	# We need an extra argument to apt-get update on buster
	extraargs="--allow-releaseinfo-change"
elif [ $RPI_OS_VERSION = "jessie" ]; then
	# Sadly, we need to fix the apt.sources on a default install, as the values that
	# are used out of the box do not work anymore on these older versions
	echo 'deb http://packages.hs-regensburg.de/raspbian/ jessie main contrib non-free rpi' | ssh -o "StrictHostKeyChecking no" -i $sshkey -p $port $username@$host "cat - | sudo tee /etc/apt/sources.list"
fi

echo "About to run: sudo apt-get update $extraargs"
ssh -o "StrictHostKeyChecking no" -i $sshkey -p $port $username@$host "sudo apt-get update $extraargs"

echo "In case anything was left in an unclean state, we run: sudo sudo dpkg --configure -a"
ssh -o "StrictHostKeyChecking no" -i $sshkey -p $port $username@$host 'sudo dpkg --configure -a'

echo "About to run: sudo apt-get -y upgrade $extraargs"
ssh -o "StrictHostKeyChecking no" -i $sshkey -p $port $username@$host 'which dpkg'
ssh -o "StrictHostKeyChecking no" -i $sshkey -p $port $username@$host 'ls -l /usr/bin/dpkg'
rc=0
ssh -o "StrictHostKeyChecking no" -i $sshkey -p $port $username@$host 'sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade' || rc=$?
if [ "$rc" != "" -a $rc -ne 0 ]; then
	echo "Error updating.  Return code: $rc"
	ssh -o "StrictHostKeyChecking no" -i $sshkey -p $port $username@$host 'which dpkg'
	ssh -o "StrictHostKeyChecking no" -i $sshkey -p $port $username@$host 'ls -l /usr/bin/dpkg'
	echo "Attempting to update again in case it was an intermittent network issue"
	ssh -o "StrictHostKeyChecking no" -i $sshkey -p $port $username@$host 'sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade'
fi
echo "About to shut down the VM"
ssh -o "StrictHostKeyChecking no" -i $sshkey -p $port $username@$host 'sudo shutdown -h now'
