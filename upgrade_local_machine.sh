#!/bin/sh -e
codename=`lsb_release -cs`

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

if [ -d /etc/apt/apt.conf.d ]; then
	echo "Changing apt timeout to be longer"
	echo 'Acquire::http::Timeout "60";' | sudo tee /etc/apt/apt.conf.d/99-timeout
	echo 'Acquire::https::Timeout "60";' | sudo tee -a /etc/apt/apt.conf.d/99-timeout
	echo "Displaying contents of /etc/apt/apt.conf.d/99-timeout"
	cat /etc/apt/apt.conf.d/99-timeout
fi

if [ $codename = "buster" ]; then
	# We need an extra argument to apt-get update on buster
	extraargs="--allow-releaseinfo-change"
elif [ $codename = "jessie" ]; then
	# Sadly, we need to fix the apt.sources on a default install, as the values that
	# are used out of the box do not work anymore on these older versions
	echo 'deb http://packages.hs-regensburg.de/raspbian/ jessie main contrib non-free rpi' | sudo tee /etc/apt/sources.list
fi

# The repo at http://raspbian.raspberrypi.org has been having network issues for
# bullseye, so we will switch to using a mirror instead.
if [ $codename = "bullseye" ]; then
	echo 'deb http://raspbian.mirrors.lucidnetworks.net/raspbian/ bullseye main contrib non-free' | sudo tee /etc/apt/sources.list
	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key 9165938D90FDDD2E
fi

echo "Updating apt package lists from repos"
sudo apt-get update $extraargs

# In case anything was left in an unclean state, we run: sudo sudo dpkg --configure -a
sudo dpkg --configure -a

echo "About to perform system upgrade"
sudo DEBIAN_FRONTEND=noninteractive apt -y upgrade

echo "Cleaning up update script"
rm $0

echo "About to shut down the VM"
nohup sudo shutdown -h now >/dev/null 2>/dev/null &
