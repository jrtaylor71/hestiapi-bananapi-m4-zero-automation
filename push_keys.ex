#!/usr/bin/expect -f
# This will generate SSH keys and push the public key to the target

# This script expects the following environment variables to be set:
# host = host to push SSH keys to
# port = port SSH should use when connecting to the remote host
# username = username for remote host
# password = password for remote host

set timeout -1
spawn ssh-keygen -t ed25519 -N "" -f ./id_25519-$env(RPI_OS_VERSION)

# Start the guest VM
# -serial is because of https://github.com/dhruvvyas90/qemu-rpi-kernel/issues/75
# and https://stackoverflow.com/questions/60552355/qemu-baremetal-emulation-how-to-view-uart-output
spawn $env(QEMU) -kernel $env(RPI_KERNEL) -usb \
    -cpu $env(RPI_CPU) -m $env(memory) -M $env(machine) \
    -dtb $env(PTB_FILE) -serial mon:stdio -no-reboot \
    $env(devicearg) "$env(device)" -nographic -audiodev none,id=none \
    -append "$env(append)" \
    $env(driveopt) "$env(drivearg)" \
    $env(netopt1) $env(netdevice) $env(netopt2) $env(netdev)
# Wait until we see a message saying SSH has been started, or
# we see a shell prompt (bullseye will auto-login if the username
# and password are set to the default values)
expect {
	-re "^.*Started.*OpenBSD Secure Shell server.*$" {
		send_user "\nDetected SSH is running\n"
	}
	-re "^.*pi@raspberrypi.*$" {
		send_user "\nDetected that we are booted to a shell\n"
	}
}
# Now give it a few seconds from when that message appears to when we try to get in
sleep 30

# We automatically accept the host key fingerprint
spawn ssh -o "StrictHostKeyChecking no" -p $env(port) $env(username)@$env(host)

# We will either get a password prompt, or a shell. Respond accordingly
expect {
	-re "^.*?assword:.*$" {
		send_user "\nPassword prompt detected, sending password\n"
		send "$env(password)\r\r"
		expect " $"

		send "mkdir -p .ssh\r"
		expect " $"

		send "chmod 700 .ssh\r"
		expect " $"

		send "echo '"
		send [exec cat ./id_25519-$env(RPI_OS_VERSION).pub]
		send "' > .ssh/authorized_keys\r"
		expect " $"

		send "chmod 600 .ssh/authorized_keys\r"
		expect " $"
	}
	" $" {
		send_user "\nShell prompt detected, keys are already set up\n"
	}
}

# Shutdown gracefully to make sure the changes to the filesystem get flushed
send_user "\nAbout to initiate shutdown\n"
send "sudo shutdown -h now\r"
send_user "\nInitiated shutdown\n"

# Wait for qemu to close the file handle to stdin
expect eof
send_user "\nGot end of file from qemu\n"

# It takes a few more seconds for the qemu process to exit, so we use
# sleep to make sure the process comes to a full and complete stop
# If there were a way to wait until the spawned process actually terminated,
# that would be preferred, but I'm not aware of any such functionality in expect
sleep 60
send_user "\nFinished waiting for qemu process to exit\n"
