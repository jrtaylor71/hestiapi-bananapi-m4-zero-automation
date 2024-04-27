#!/usr/bin/expect -f
# This script will boot a VM in qemu and wait for it to get to the login
# prompt.  It expects the following environment variables to be set:
#
# QEMU       - Name of qemu executable for ARM system emulation
# RPI_CPU    - CPU of Raspberry Pi being emulated
# RPI_KERNEL - Filename of kernel to boot
# RPI_FS     - Filename of disk image (filesystem) to boot
# PTB_FILE   - Filename of PTB file (device tree binary)
#

# Don't time out waiting for the machine to boot
set timeout -1

# Start the VM
# -serial is because of https://github.com/dhruvvyas90/qemu-rpi-kernel/issues/75
# and https://stackoverflow.com/questions/60552355/qemu-baremetal-emulation-how-to-view-uart-output
spawn $env(QEMU) -kernel $env(RPI_KERNEL) -usb \
    -cpu $env(RPI_CPU) -m $env(memory) -M $env(machine) \
    -dtb $env(PTB_FILE) -serial mon:stdio -no-reboot \
    $env(devicearg) "$env(device)" -nographic \
    -append "$env(append)" \
    $env(driveopt) "$env(drivearg)" \
    $env(netopt1) $env(netdevice) $env(netopt2) $env(netdev)
set qemu_handle $spawn_id
send_user "\nboot_vm.ex: qemu spawn id = $qemu_handle\n"

# Wait for the login prompt or a shell
expect {
	"login: " { }
	"pi@raspberrypi" { }
}

# Run the script that was passed in as a variable
set script [lindex $argv 0];
send_user "\nStarting script: $script\n"
spawn "../$script"
send_user "\nboot_vm.ex: $script spawn id = $spawn_id\n"

# wait for the script to finish
expect eof
send_user "\nboot_vm.ex: EOF received from $script"

# check return code of the script
catch wait result

# The script should shut down qemu as its final step
# This means we can just wait for the qemu process to exit, however...
# Due to qemu not having implemented the power control parts of the raspberry pi
# 3 (https://gitlab.com/qemu-project/qemu/-/issues/64), we have to just bail.
# In an attempt to be civil, we give the VM a short time to wrap things up.
sleep 45

# bubble up any errors that the script might have had
exit [lindex $result 3]
