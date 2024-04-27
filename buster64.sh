#!/bin/sh
# I set environment variables so build_emulator.sh can use a buster image.

export RPI_KERNEL=kernel8.img
export RPI_KERNEL_URL=https://github.com/raspberrypi/firmware/blob/master/boot/${RPI_KERNEL}?raw=true
export PTB_FILE=bcm2710-rpi-zero-2-w.dtb
export PTB_FILE_URL=https://github.com/raspberrypi/firmware/blob/master/boot/${PTB_FILE}?raw=true
export IMAGE_FILE=2021-05-07-raspios-buster-arm64-lite.img
export IMAGE_FILE_URL=https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2021-05-28/2021-05-07-raspios-buster-arm64-lite.zip
export username="pi"
if [ -z $password ] ; then
	export password="raspberry"
fi

# Warning: The buster image doesn't seem to boot on an emulated rPi 3b.
#          It's not clear why, but the exact same qemu options boot the
#          bullseye image without any problems.  Sorry buster!

# This is for the 64-bit arm architecture (e.g., the Raspberry Pi Zero 2)
export arch=aarch64
export memory=1024
export machine=raspi3b
export imagesize=4G
export driveopt="-drive"
# Disable selinux because it kernel panics in qemu when the shutdown command is run
export append="console=ttyAMA0 root=/dev/mmcblk0p2 panic=1 rootwait rootfstype=ext4 selinux=0 rw"
#export driveopt="-sd"
export drivearg="file=$IMAGE_FILE,if=sd,format=raw"
export devicearg="-k"
export device="en-us"
# See comments in bullseye64.sh for why we use a USB network interface
export netopt1="-device"
export netdevice="usb-net,netdev=net0"
export netopt2="-netdev"
export netdev="user,id=net0,hostfwd=tcp::5022-:22,hostfwd=tcp::8080-:8080"
export blockdev="/dev/mmcblk0"
export blockdevpartition="mmcblk0p2"
