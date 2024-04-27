#!/bin/sh
# I set environment variables so build_emulator.sh can use a bullseye image.

export RPI_KERNEL=kernel8.img
export RPI_KERNEL_URL=https://github.com/raspberrypi/firmware/blob/master/boot/${RPI_KERNEL}?raw=true
export PTB_FILE=bcm2710-rpi-zero-2-w.dtb
#export PTB_FILE=bcm2710-rpi-2-b.dtb
export PTB_FILE_URL=https://github.com/raspberrypi/firmware/blob/master/boot/${PTB_FILE}?raw=true
export IMAGE_FILE=2022-09-22-raspios-bullseye-arm64-lite.img
export IMAGE_FILE_URL=https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-09-26/${IMAGE_FILE}.xz
export username="pi"
if [ -z $password ] ; then
	export password="raspberry"
fi

# This is for the 64-bit arm architecture.
# There is no "machine" in qemu for the
# Raspberry Pi Zero 2, so we have to use the
# raspi3b.  For the CPU, choose cortex-a53
if [ -z "$RPI_CPU" ]; then
	export RPI_CPU="cortex-a53"
fi
export arch=aarch64
export memory=1024
export machine=raspi3b
export imagesize=4G
# Disable selinux because it kernel panics in qemu when the shutdown command is run
export append="console=ttyAMA0 root=/dev/mmcblk0p2 panic=1 rootwait rootfstype=ext4 selinux=0 rw"
export driveopt="-drive"
export drivearg="file=$IMAGE_FILE,if=sd,format=raw"
# We can't have any empty arguments, or qemu freaks out
# so we explicitly give it a default keyboard layout
# if we don't have a device we want to assign
###export device="usb-mouse"
export devicearg="-k"
export device="en-us"
# Using "-net nic -net user,hostfwd=tcp::5022-:22,hostfwd=tcp::8080-:8080"
# fails when emulating the raspi3b hardware with the following errors:
#   qemu-system-aarch64: warning: hub port hub0port0 has no peer
#   qemu-system-aarch64: warning: hub 0 with no nics
#   qemu-system-aarch64: warning: netdev hub0port0 has no peer
#   qemu-system-aarch64: warning: requested NIC (__org.qemu.net0, model unspecified) was not created (not supported by this machine?)
#
# We also can not use "-device virtio-net-device,netdev=net0" for the
# network because there's no virtio bus. The error is as follows:
#   No 'virtio-bus' bus found for device 'virtio-net-device'
#
# Similarly, we can't use "-device virtio-net-pci,netdev=net0" because
# there is no PCI bus.
#   No 'PCI' bus found for device 'virtio-net-pci'
#
# So we use a USB network adapter.
export netopt1="-device"
export netdevice=usb-net,netdev=net0
export netopt2="-netdev"
export netdev=user,id=net0,hostfwd=tcp::5022-:22,hostfwd=tcp::8080-:8080
export blockdev="/dev/mmcblk0"
export blockdevpartition="mmcblk0p2"
