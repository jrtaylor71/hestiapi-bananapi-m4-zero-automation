#!/bin/sh -e
# I build emulators using scripts you can use to configure actual Pis.
# See README.md for more information.
set -e


#
# Command line arguments
#

if [ "$#" -lt "2" ]; then
	echo "Usage: $0 [CPU] [BASE_VERSION] [CONFIG ...]"
	echo ""
	echo "  CPU          - the CPU to emulate (default: arm1176)"
	echo "  BASE_VERSION - the version of raspbian to put on the emulated pi (default: buster)"
	echo "  CONFIG       - the name of a script that configures the pi (e.g. wrapper.sh)"
	echo ""
	exit 1
fi

if [ -z "$1" ]; then
	export RPI_CPU="arm1176"
else
	export RPI_CPU="$1"
fi
shift

if [ -z "$1" ]; then
	export RPI_OS_VERSION="buster"
else
	export RPI_OS_VERSION="$1"
fi
shift


#
# Environment variables
#
echo "build_emulator.sh - Displaying proxy information:"
echo "HTTP_PROXY = $HTTP_PROXY"
echo "HTTPS_PROXY = $HTTPS_PROXY"
echo "http_proxy = $http_proxy"
echo "https_proxy = $https_proxy"
if [ -f .profile ]; then
	echo "Displaying $HOME/.profile"
	cat .profile
fi

# The default Rasbian image is 1.5GB.  If you want something bigger, change
# EXPAND_BY to be the number of MB to add on to the image.
if [ -z "$EXPAND_BY" ]; then
  # Default to expanding the image by 2GB
  EXPAND_BY=$((2*1024))  # 2GB
fi


#
# Do it
#

if [ -x /usr/bin/lsb_release ]; then
    identifier=$(lsb_release -i | sed 's/.*:\s*//g' | tr [A-Z] [a-z] || true)
fi
if [ -z "$identifier" ]; then  # this happens if lsb_release isn't installed
    identifier=$(grep ^ID= /etc/os-release | sed 's/.*=//g')
fi
echo "Distribution is: $identifier"
if [ "$identifier" = "debian" -o "$identifier" = "ubuntu" ]; then
    # Debian-based distro; use apt to ensure we have qemu-system-arm & expect
    echo "Checking for dependencies"
    # Root does not need to use sudo
    if [ "`whoami`" = "root" ]; then
        sudo=""
    else
        sudo="sudo"
    fi

    export DEBIAN_FRONTEND=noninteractive
    for package in qemu-system-arm expect wget unzip mtools fdisk openssl; do
        exists=1
        which $package || ls /sbin/$package || exists=0
        if [ "$exists" -eq 0 ]; then
            $sudo apt-get update
            $sudo apt-get install -y $package
        fi
    done
    # SSH, xz, and qemu-img have different executable and package names
    exists=1
    which ssh || exists=0
    if [ "$exists" -eq 0 ]; then
        $sudo apt-get update
        $sudo apt-get install -y openssh-client
    fi
    exists=1
    which xz || exists=0
    if [ "$exists" -eq 0 ]; then
        $sudo apt-get update
        $sudo apt-get install -y xz-utils
    fi
    exists=1
    which qemu-img || exists=0
    if [ "$exists" -eq 0 ]; then
        $sudo apt-get update
        $sudo apt-get install -y qemu-utils
    fi
    # Notes: If we need to manipulate ext2 filesystems in the future, we should
    # use e2tools or genext2fs.
    # Reference: https://stackoverflow.com/questions/11202706/create-a-virtual-floppy-image-without-mount
    echo "Dependencies are all installed"
fi
# for Macs
#brew install qemu

. ./${RPI_OS_VERSION}.sh

## Default to the older, arm (32-bit) based pi
#if [ -z "$arch" ]; then
#    export arch=arm
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
#if [ -z "$drivearg" -a -z "$driverarg" ]; then
#    if [ "$driveopt" = "-sd" ]; then
#        export drivearg="$IMAGE_FILE"
#    else
#        export drivearg="file=$IMAGE_FILE,index=0,media=disk,format=raw"
#    fi
#fi
#if [ -z "$device" ]; then
#    export device=""
#    export devicearg=""
#else
#    if [ -z "$devicearg" ]; then
#        export devicearg="-device"
#    fi
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
#if [ -z "$blockdev" ]; then
#    export blockdev="/dev/sda"
#fi
#if [ -z "$blockdevpartition" ]; then
#    export blockdevpartition="sda2"
#fi

export QEMU=$(which qemu-system-$arch)
export TMP_DIR=./qemu-rpi

mkdir -p $TMP_DIR; cd $TMP_DIR

# If we have the kernel checked in, we'll avoid downloading it
if [ -f ../${RPI_KERNEL} ]; then
    echo "Kernel found locally, copying to `pwd`/$RPI_KERNEL"
    cp ../${RPI_KERNEL} .
fi
if [ ! -f ${RPI_KERNEL} ]; then
    echo "Fetching ${RPI_KERNEL} for ${RPI_OS_VERSION%%[0-9]*}"
    wget -q ${RPI_KERNEL_URL} -O ${RPI_KERNEL}
fi

# If we have the device tree file checked in, we'll avoid downloading it
if [ -f ../${PTB_FILE} ]; then
    cp ../${PTB_FILE} .
fi
if [ ! -f ${PTB_FILE} ]; then
    echo "Fetching ${PTB_FILE}"
    wget -q ${PTB_FILE_URL} -O ${PTB_FILE}
fi

# If we don't have the zip file, download it
if [ ! -f ${IMAGE_FILE_URL##*/} ]; then
    echo "Fetching ${IMAGE_FILE_URL##*/}"
    wget -q ${IMAGE_FILE_URL}
fi
# If we don't have the image file, extract it
if [ ! -f $IMAGE_FILE ]; then
    echo "Extracting disk image: ${IMAGE_FILE_URL##*/}"
    # Old images use zip compression, new ones use xz
    unzip ${IMAGE_FILE_URL##*/} || xz -d < ${IMAGE_FILE_URL##*/} > $IMAGE_FILE
fi

# If we still don't have the image file, abort
if [ ! -f $IMAGE_FILE ]; then
    echo "Unable to find disk image file: $IMAGE_FILE"
    exit 1
fi

# As of bullseye, there's no longer a default user, so we have to create one.
# Source: https://www.raspberrypi.com/news/raspberry-pi-bullseye-update-april-2022/

# If it is not any of the old versions that we support, we assume it is bullseye
# or later.
p1_start=`/sbin/fdisk -l $IMAGE_FILE | grep FAT | awk '{print $2}'`
if [ "$RPI_OS_VERSION" != "jessie" -a \
     "$RPI_OS_VERSION" != "stretch" -a \
     "$RPI_OS_VERSION" != "buster" ]; then
    echo "Adding user $username to the image"
    echo -n "$username:" > userconf
    echo "$password" | openssl passwd -6 -stdin >> userconf

    echo "Partition offset found for /boot at sector $p1_start"
    mcopy -novi $IMAGE_FILE@@$((p1_start*512)) userconf ::userconf
    echo "userconf file copied over to /boot partition"

    touch ssh
    mcopy -novi $IMAGE_FILE@@$((p1_start*512)) ssh ::ssh
    echo "ssh file copied over to /boot partition"
fi

# If we have a kernel in /boot of the disk image, we prefer that to the
# one we downloaded from github (as they can and do get out of sync)
# Thanks LSerni! https://stackoverflow.com/a/65755186
file_found=1
mdir -i $IMAGE_FILE@@$((p1_start*512)) ::$RPI_KERNEL 2> /dev/null || file_found=0
if [ $file_found -eq 1 ]; then
    echo "Copying $RPI_KERNEL from $IMAGE_FILE"
    mcopy -novi $IMAGE_FILE@@$((p1_start*512)) ::$RPI_KERNEL $RPI_KERNEL
fi
# Same goes for the PTB file
file_found=1
mdir -i $IMAGE_FILE@@$((p1_start*512)) ::$PTB_FILE 2> /dev/null || file_found=0
if [ $file_found -eq 1 ]; then
    echo "Copying $PTB_FILE from $IMAGE_FILE"
    mcopy -novi $IMAGE_FILE@@$((p1_start*512)) ::$PTB_FILE $PTB_FILE
fi

# If we have a specific image size that needs to be used, resize it now
if [ ! -z "$imagesize" ]; then
    echo "Resizing image to $imagesize"
    qemu-img resize -f raw "$IMAGE_FILE" "$imagesize"
elif [ ! -z $EXPAND_BY -a "$EXPAND_BY" -ne 0 ]; then
    # the legacy method of resizing disk images
    echo "Expanding image by ${EXPAND_BY}MB"
    dd if=/dev/zero count=$EXPAND_BY bs=$((1024*1024)) >> $IMAGE_FILE
fi

# SSH is disabled by default, need to enable it via the console if we didn't do so earlier
if [ "$RPI_OS_VERSION" = "jessie" -o \
     "$RPI_OS_VERSION" = "stretch" -o \
     "$RPI_OS_VERSION" = "buster" ]; then
	echo "Enabling SSH"
	export RPI_FS="$IMAGE_FILE"
	../turn_on_ssh.ex
	echo "SSH enabled"
fi

while [ $# -gt 0 ]
do
    RPI_CONFIG="$1"
    echo "Running ${RPI_CONFIG}"
    pwd
    ../${RPI_CONFIG}
    shift
done
