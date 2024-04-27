#!/bin/sh -e
if [ -z "$RPI_OS_VERSION" ]; then
	RPI_OS_VERSION=`lsb_release -cs`
fi
# This will SSH into the VM and shut it down
export sshkey="id_25519-$RPI_OS_VERSION"
export host=127.0.0.1
export port=5022
export username="pi"

ssh -o "StrictHostKeyChecking no" -i $sshkey -p $port $username@$host 'sudo shutdown -h now'
