#!/bin/sh
# I set environment variables so build_emulator.sh can use a bullseye image.

if [ -z $RPI_KERNEL ] ; then
	export RPI_KERNEL=kernel-qemu-5.10.63-bullseye
fi
export RPI_KERNEL_URL=https://github.com/dhruvvyas90/qemu-rpi-kernel/blob/master/${RPI_KERNEL}?raw=true
if [ -z $PTB_FILE ] ; then
	export PTB_FILE=versatile-pb-bullseye-5.10.63.dtb
fi
export PTB_FILE_URL=https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/${PTB_FILE}
export IMAGE_FILE=2022-09-22-raspios-bullseye-armhf-lite.img
export IMAGE_FILE_URL=https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2022-09-26/${IMAGE_FILE}.xz
export username="pi"
if [ -z $password ] ; then
	export password="raspberry"
fi

export imagesize="5G"
export arch="arm"
export memory=256
export machine="versatilepb"
export append="root=/dev/sda2 panic=1 rootfstype=ext4 rw"
export driveopt="-drive"
export drivearg="file=$IMAGE_FILE,index=0,media=disk,format=raw"
export devicearg="-device"
export device="virtio-rng-pci"
export netopt1="-net"
export netdevice="nic"
export netopt2="-net"
export netdev="user,hostfwd=tcp::5022-:22,hostfwd=tcp::8080-:8080"
export blockdev="/dev/sda"
export blockdevpartition="sda2"
