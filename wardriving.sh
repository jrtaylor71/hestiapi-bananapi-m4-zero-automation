#!/bin/sh -e
#
# This script will transform a normal raspberry pi running Debian into a
# wardriving machine.  The pi will attempt to get it's location using a
# GPS, and sniff wifi using kismet.  Data will be written to /mnt, which
# will have a thumb drive mounted there (if there is a thumb drive to
# mount).
#
# The pi is expected to not have a keyboard nor a monitor attached.  To
# shut down gracefully, unplug a USB device such as the wifi adapter or
# GPS hardware.  This will trigger USBkill to shut down the computer and
# flush data to all disks.
#
# This script is expecting to be run on the pi itself, as a user root and it
# is also expecting to be connected to the internet for this initial setup
# process.  After the setup is done, everything can run without network
# connectivity, as that is the expected mode of operation.
#
export DEBIAN_FRONTEND=noninteractive

if [ "$USER" != "root" ]; then
	sudo $0 $@
	exit $?
fi

# Load .profile settings, which include proxy information, if relevant
if [ -f $HOME/.profile ]; then
	echo "Displaying $HOME/.profile"
	cat $HOME/.profile
	echo "Loading $HOME/.profile"
	. $HOME/.profile
fi
echo "Displaying proxy information:"
echo "HTTP_PROXY = $HTTP_PROXY"
echo "HTTPS_PROXY = $HTTPS_PROXY"
echo "http_proxy = $http_proxy"
echo "https_proxy = $https_proxy"

# Add kismet's apt repos and PGP key
wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key | apt-key add -
codename=`lsb_release -cs`
echo "deb https://www.kismetwireless.net/repos/apt/release/$codename $codename main" > /etc/apt/sources.list.d/kismet.list
apt-get update

# Install the software required to collect the data
apt-get install -y screen kismet gpsd git python3-distutils

# We want to mount a USB drive if it's present.  The USB drive will
# appear as /dev/sda and we expect the first partition to be ext4.
# If there is no thumb drive, things should continue one without any
# problem.
# In qemu the root partition is not an SSD, but instead it shows up
# as /dev/sda. In this case we want it to quietly fail in the same
# way as it would if there were no USB drive present.
echo '[Unit]
Description=USB drive

[Mount]
What=/dev/sda1
Where=/mnt
Type=ext4
Options=defaults,nofail
' > /etc/systemd/system/mnt.mount
systemctl daemon-reload


# Configure kismet to use wlan0, if a source is not already configured
grep "^ncsource=" /etc/kismet/kismet.conf || echo "ncsource=wlan0" >> /etc/kismet/kismet.conf
# Set up kismet_server as a systemd service. The working directory
# is optional to avoid kismet.service from failing when nothing is
# mounted there.
echo '[Unit]
Description=Kismet
Wants=mnt.mount
After=network.target gpsd.service mnt.mount

[Service]
ExecStart=/usr/bin/kismet_server
WorkingDirectory=-/mnt
Restart=always

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/kismet.service
systemctl daemon-reload
systemctl enable --now kismet


# Set up USB kill to allow a graceful shutdown without a keyboard
if [ ! -d usbkill ]; then
	git clone https://github.com/hephaest0s/usbkill
fi
cd usbkill
python setup.py build install
cd ..
echo '[Unit]
Description=USB kill

[Service]
ExecStart=/usr/local/bin/usbkill

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/usbkill.service
systemctl daemon-reload
systemctl enable --now usbkill


# Install the software required to process the data
apt-get install -y git libxml-libxml-perl libdbi-perl libdbd-sqlite3-perl
if [ ! -d giskismet ]; then
	git clone https://github.com/xtr4nge/giskismet.git
fi
cd giskismet
perl Makefile.PL
make
make install
cd ..

# To import all the APs from the netxml file:
# giskismet -x Kismet-whatever.netxml

# To generate a kml file containing the entire database
# giskismet -q "select * from wireless" -o whatever.kml

# giskismet does not NEED to be installed on the pi, as it's just used for
# post-processing and the pi can just stick to data capture.

# If you want, you can boot up the pi with a keyboard and monitor when you
# get home and use giskismet to do the processing.  Alternatively, you can
# run the same commands above on another computer and do the post-processing
# there instead.

echo "Setup complete, shutting down"
nohup shutdown -h now >/dev/null 2>/dev/null &
