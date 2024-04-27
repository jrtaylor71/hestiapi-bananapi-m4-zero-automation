#!/bin/sh -e
#
# Expects the following environment variables to be set:
#   * IMAGE_FILE
#   * RPI_KERNEL
#
export DEBIAN_FRONTEND=noninteractive
for package in mtools fdisk; do
    exists=1
    which $package || ls /sbin/$package || exists=0
    if [ "$exists" -eq 0 ]; then
        $sudo apt-get update
        $sudo apt-get install -y $package
    fi
done

# If we have a kernel in /boot of the disk image, we prefer that to the
# one we downloaded from github (as they can and do get out of sync)
# Thanks LSerni! https://stackoverflow.com/a/65755186
p1_start=`/sbin/fdisk -l $IMAGE_FILE | grep FAT | awk '{print $2}'`
file_found=1
mdir -i $IMAGE_FILE@@$((p1_start*512)) ::$RPI_KERNEL || file_found=0
if [ $file_found -eq 1 ]; then
    echo "Copying $RPI_KERNEL from $IMAGE_FILE"
    mcopy -novi $IMAGE_FILE@@$((p1_start*512)) ::$RPI_KERNEL $RPI_KERNEL
fi
