#!/usr/bin/expect -f
# Thanks https://stackoverflow.com/questions/3146013/qemu-guest-automation !
# This script expects the following environment variables to be set:
# QEMU       - Name of qemu executable for ARM system emulation
# RPI_CPU    - CPU of Raspberry Pi being emulated
# RPI_KERNEL - Filename of kernel to boot
# RPI_FS     - Filename of disk image (filesystem) to boot
# PTB_FILE   - Filename of PTB file (device tree binary)
# username   - User to login as (e.g. "pi")
# password   - User's password (e.g. "raspberry")

#starts guest vm, run benchmarks, poweroff
set timeout -1

#Assign a variable to the log file
set log     [lindex $argv 0]

#Enable hella logging
exp_internal -f /tmp/expect.log 0

# Start the guest VM
# -serial is because of https://github.com/dhruvvyas90/qemu-rpi-kernel/issues/75
# and https://stackoverflow.com/questions/60552355/qemu-baremetal-emulation-how-to-view-uart-output
spawn $env(QEMU) -kernel $env(RPI_KERNEL) -usb \
    -cpu $env(RPI_CPU) -m $env(memory) -M $env(machine) \
    -dtb $env(PTB_FILE) -serial mon:stdio -no-reboot \
    $env(devicearg) "$env(device)" -nographic \
    -append "$env(append)" \
    $env(driveopt) "$env(drivearg)" \
    $env(netopt1) $env(netdevice) $env(netopt2) $env(netdev)
send_user "\nturn_on_ssh.ex: qemu spawn id = $spawn_id\n"

#Login process
expect "login: "

send_user "\nturn_on_ssh.ex: sending username $env(username)\n"
#Enter username
send "$env(username)\r"

#Enter Password
expect "Password: "
send_user "\nturn_on_ssh.ex: sending password $env(password)\n"
send "$env(password)\r"
send_user "\nturn_on_ssh.ex: waiting for shell prompt\n"
expect "$ "
send_user "\nturn_on_ssh.ex: shell prompt detected, continuing...\n"

send "sudo systemctl enable ssh\r"
send_user "\nturn_on_ssh.ex: enabling ssh service...\n"

send_user "\nturn_on_ssh.ex: all done, shutting down qemu now\n"
send "sudo shutdown -h now\r"

# Wait for the qemu process to exit (thereby sending us an EOF)
expect {
	eof { exit 0 }
	"Rebooting" { exit 0 }
}
