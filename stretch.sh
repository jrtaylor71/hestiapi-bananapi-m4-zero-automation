#!/bin/sh
# I set environment variables so build_emulator.sh can use a stretch image.

export RPI_KERNEL=kernel-qemu-4.14.79-stretch
export RPI_KERNEL_URL=https://github.com/dhruvvyas90/qemu-rpi-kernel/blob/master/kernel-qemu-4.14.79-stretch?raw=true
export PTB_FILE=versatile-pb.dtb
export PTB_FILE_URL=https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/${PTB_FILE}
if [ -z "$IMAGE_FILE" ]; then
	export IMAGE_FILE=2018-11-13-raspbian-stretch-lite.img
fi
export IMAGE_FILE_URL=http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2018-11-15/2018-11-13-raspbian-stretch-lite.zip
export username="pi"
if [ -z $password ] ; then
	export password="raspberry"
fi

export imagesize="4G"
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
