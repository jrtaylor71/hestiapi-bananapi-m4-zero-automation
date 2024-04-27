#!/bin/sh
# This script will pick up where you left off after shutting down your Rasbian
# VM.

if [ "$#" -ne "2" ]; then
	echo "Usage: $0 CPU BASE_VERSION"
	echo ""
	echo "  CPU          - the CPU to emulate"
	echo "  BASE_VERSION - the version of raspbian to put on the emulated pi"
	echo ""
	exit 1
fi

export RPI_CPU="$1"
RPI_OS_VERSION="$2"

. ./${RPI_OS_VERSION}.sh

#if [ -z "$arch" ]; then
#    arch=arm
#fi
#if [ -z "$memory" ]; then
#    export memory=256
#fi
#if [ -z "$machine" ]; then
#    export machine=versatilepb
#fi
#if [ -z "$append" ]; then
#    export append="root=/dev/sda2 panic=1 rootfstype=ext4 rw"
#fi
#if [ -z "$driveopt" ]; then
#    export driveopt="-drive"
#fi
#if [ -z "$drivearg" ]; then
#    if [ "$driveopt" = "-sd" ]; then
#        export drivearg="$IMAGE_FILE"
#    else
#        export drivearg="file=$IMAGE_FILE,index=0,media=disk,format=raw"
#    fi
#fi
#if [ -z "$device" ]; then
#    export device=virtio-rng-pci
#fi
#if [ -z "$devicearg" ]; then
#    export devicearg="-device"
#fi
#if [ -z "$netopt1" ]; then
#    export netopt1="-net"
#fi
#if [ -z "$netdevice" ]; then
#    export netdevice=nic
#fi
#if [ -z "$netopt2" ]; then
#    export netopt2="-net"
#fi
#if [ -z "$netdev" ]; then
#    export netdev="user,hostfwd=tcp::5022-:22,hostfwd=tcp::8080-:8080"
#fi
export QEMU=$(which qemu-system-$arch)
export TMP_DIR=./qemu-rpi

cd $TMP_DIR
export RPI_FS=`ls -t *-rasp*-${RPI_OS_VERSION%%[0-9]*}-*lite.img | head -n 1`
# Start the guest VM
# -serial is because of https://github.com/dhruvvyas90/qemu-rpi-kernel/issues/75
# and https://stackoverflow.com/questions/60552355/qemu-baremetal-emulation-how-to-view-uart-output
$QEMU -kernel $RPI_KERNEL -usb \
    -cpu $RPI_CPU -m $memory -M $machine \
    -dtb $PTB_FILE -no-reboot -serial mon:stdio \
    $devicearg $device -nographic \
    -append "$append" \
    $driveopt "$drivearg" \
    $netopt1 $netdevice $netopt2 $netdev
