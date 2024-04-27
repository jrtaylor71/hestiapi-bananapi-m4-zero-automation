#!/bin/sh -e
#
# This script will transform a normal raspberry pi running Debian into a
# HestiaPi.  It is expecting to be run on the pi itself, as a user who has
# passwordless sudo access.
#
echo "Running $0 now"

# We want to be SURE the filesystem is always as big as the partition
# Sometimes earlier attempts at doing so fail because the partition
# resizing sometimes requires a reboot (depends on kernel version)
sudo resize2fs /dev/sda2 || sudo resize2fs /dev/mmcblk0p2

# Set up sudo access for openhab
echo 'openhab ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/020_openhab-nopasswd

if [ -x /usr/bin/lsb_release ]; then
	codename=$(lsb_release -cs)
else
	if [ -f /etc/os-release ]; then
		. /etc/os-release
		version=$(echo ${VERSION#*\(})
		codename=$(echo ${version%)*})
	fi
fi

if [ "$codename" = "jessie" ]; then
	# Sadly, we need to fix the apt.sources on a default install, as the values that
	# are used out of the box do not work anymore (to be fair jessie is very old)
	echo 'deb http://packages.hs-regensburg.de/raspbian/ jessie main contrib non-free rpi' | sudo tee /etc/apt/sources.list
fi

echo "Checking for mirrordirector in /etc/apt/"
grep -R mirrordirector /etc/apt || echo "mirrordirector not found"

# Finally, we make sure that if there were any previous errors in configuring
# any packages, we make sure they are resolved before we try to update anything
sudo DEBIAN_FRONTEND=noninteractive dpkg --configure -a

# And now we should be able to run apt-get update without any problems
echo "About to run apt-get update"
sudo apt-get update
echo "About to run apt-get upgrade"
sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

###
# Dependencies
###
echo "Running apt-get update prior to installing packages"
sudo apt-get update
echo "Installing first batch of packages"
sudo apt-get install -y apt-transport-https bc git accountsservice libssl-dev build-essential quilt devscripts cmake libc-ares-dev daemon zip zlib1g zlib1g-dev unclutter matchbox-window-manager xwit xinit openbox lxterminal geoclue-2.0
# Bullseye doesn't have zlibc
sudo apt-get install -y zlibc || true
# Bullseye doesn't have libjavascriptcoregtk-3.0-0
sudo apt-get install -y libjavascriptcoregtk-4.0-bin || sudo apt-get install -y libjavascriptcoregtk-3.0-0

APT_VERSION=`apt --version 2> /dev/null | head -n 1 | sed 's/apt \([0-9\.]*\).*/\1/g'`
echo "Detected apt version $APT_VERSION"
if [ $APT_VERSION = "1.0.9.8.4" -o "$APT_VERSION" = "1.0.9.8.6" ]; then
	# These versions of apt (used in jessie) does not understand the --allow-downgrades option
	allow_downgrades="--force-yes"
else
	allow_downgrades="--allow-downgrades"
fi
# packages that require specific dependencies (solved):
echo "Installing specific versions of packages"
if [ "$codename" = "jessie" ]; then
	echo "Running apt-get update again prior to installing packages"
	sudo apt-get update
	sudo apt-get install -y $allow_downgrades dnsmasq=2.72-3+deb8u5
	sudo apt-get install -y $allow_downgrades hostapd libnl-route-3-200=3.2.24-2 libnl-3-200=3.2.24-2 libnl-genl-3-200=3.2.24-2 libgtk-3-0
	sudo apt-get install -y $allow_downgrades vim vim-common=2:7.4.488-7+deb8u4
	# Note: python3-flask has dependencies that require Python < 3.5
	# The default version of python3 for jessie is now 3.5.3-1, which means we need
	# to downgrade to 3.4.  However, the default version of findutils
	# (4.6.0+git+20161106-2), which also includes xargs, breaks libpython3.4-minimal
	# This means we need to downgrade to findutils 4.4.2-9, which doesn't have this
	# problem.
	sudo apt-get install -y $allow_downgrades findutils=4.4.2-9
	echo "Running apt-get update again prior to installing python"; sudo apt-get update
	sudo apt-get install -y $allow_downgrades python3-flask python3-jinja2 python3-markupsafe python3-requests python python-setuptools python-smbus python3=3.4.2-2 python3.4 python3-minimal=3.4.2-2 libpython3-stdlib=3.4.2-2 python3.4-minimal=3.4.2-1+deb8u7 libpython3.4-stdlib=3.4.2-1+deb8u7 libpython3.4-minimal=3.4.2-1+deb8u7
	sudo apt-get install -y $allow_downgrades uuid-dev libuuid1=2.25.2-6
	sudo apt-get install -y $allow_downgrades dirmngr gnupg=1.4.18-7+deb8u5
	sudo apt-get install -y $allow_downgrades libwebkitgtk-3.0-0 libegl1-mesa=10.3.2-1+deb8u2
else
	sudo apt-get install -y dnsmasq hostapd vim python3-flask python3-requests python3-smbus uuid-dev dirmngr libwebkitgtk-3.0-0
fi
echo "Running apt-get update again prior to installing the final set of packages"
sudo apt-get update
sudo apt-get install -y --no-install-recommends xserver-xorg
sudo apt-get autoremove -y

touch /home/pi/.xinitrc \
&& chmod 755 /home/pi/.xinitrc \
&& printf '#!/bin/sh\nexec openbox-session\n' | tee --append /home/pi/.xinitrc;

echo 0 | sudo update-alternatives --config x-window-manager
sudo update-alternatives --config x-session-manager  # should say there is only one alternative
sudo cp /etc/wpa_supplicant/ifupdown.sh /etc/ifplugd/action.d/ifupdown


###
# MQTT
###
if [ "$codename" = "jessie" ]; then
	# In jessie, we need to compile mosquitto to get websocket support
	sudo apt-get remove mosquitto -y
	cd
	wget -q https://github.com/warmcat/libwebsockets/archive/v2.4.1.zip
	unzip v2.4.1.zip
	cd libwebsockets-2.4.1/
	mkdir -p build
	cd build
	cmake ..
	sudo make install || true
	echo "Done installing libwebsockets-2.4.1"
	sudo ldconfig
	echo "Done with ldconfig"

	# The latest version of mosquitto fails to compile on jessie:
	#   ../lib/libmosquitto.so.1: undefined reference to `SSL_CTX_set_alpn_protos'
	# This appears to be due to mosquitto-1.6.0 and later requiring OpenSSL 1.1
	#   https://github.com/eclipse/mosquitto/issues/1349
	if [ "$codename" = "jessie" ]; then
		# Jessie only has OpenSSL 1.0, so we'll use mosquito 1.4.9
		version="1.4.9"   # Used in https://github.com/HestiaPi/hestia-touch-openhab/wiki/Manual-Installation-ONE
		#version="1.5.11" # works with OpenSSL 1.0
	else
		# If on stretch or later and you want to compile your own...
		version="1.6.0"  # needs OpenSSL 1.1
	fi
	cd
	echo "Obtaining mosquitto $version source code"
	wget -q http://mosquitto.org/files/source/mosquitto-${version}.tar.gz
	tar -zxf mosquitto-${version}.tar.gz
	echo "changing to the mosquitto directory"
	cd mosquitto-${version}
	sed -i -e "s/WITH_WEBSOCKETS:=no/WITH_WEBSOCKETS:=yes/g" config.mk
	echo "About to compile mosquitto"
	make
	echo "Done compiling mosquitto"
	sudo make install
	echo "Done installing mosquitto"
	mkdir -p /etc/mosquitto
	echo "Copying over default mosquitto configuration file"
	sudo cp mosquitto.conf /etc/mosquitto/mosquitto.conf
	printf 'user pi\n' | sudo tee --append /etc/mosquitto/mosquitto.conf
	echo "Removing mosquitto from rc.d"
	sudo update-rc.d mosquitto remove
	printf '[Unit]\nDescription=MQTT v3.1 message broker\nAfter=network.target\nRequires=network.target\n\n[Service]\nType=simple\nExecStart=/usr/local/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf\nRestart=always\nUser=pi\n\n[Install]\nWantedBy=multi-user.target\n' | sudo tee /etc/systemd/system/mosquitto.service
	echo "Reloading, enabling and starting mosquitto service"
	sudo systemctl daemon-reload
	sudo systemctl unmask mosquitto
	sudo systemctl enable mosquitto
	sudo systemctl start mosquitto.service
	echo "Cleaning up temporary files"
	sudo rm -rf /home/pi/.cmake /home/pi/libwebsockets-2.4.1 /home/pi/mosquitto-${version} /home/pi/mosquitto-${version}.tar.gz /home/pi/v2.4.1.zip
else
	sudo apt-get install -y mosquitto
fi
echo "Updating mosquitto configuration files"
printf 'port 1883\nlistener 9001\nprotocol websockets\n' | sudo tee --append /etc/mosquitto/mosquitto.conf
# Only add the pid_file line if it is not already there
grep -q pid_file /etc/mosquitto/mosquitto.conf || printf "pid_file /var/run/mosquitto.pid\n" | sudo tee --append  /etc/mosquitto/mosquitto.conf
sudo systemctl restart mosquitto.service  # restart to pick up the new config
cd

###
# LCD
###
git clone https://github.com/goodtft/LCD-show.git
chmod -R 755 LCD-show
cd LCD-show/
# We don't want to reboot right now, so we'll patch that part out
sed -i 's/^sudo reboot/#sudo reboot/' ./LCD35-show
# Force wget to use IPv4 so the build succeeds on systems that don't have IPv6
sed -i 's/wget /wget -4 /' ./LCD35-show
# On Jessie, never try to install the local version of xserver-xorg-input-evdev
if [ "$codename" = "jessie" ]; then
	sed -i 's/input_result=1/input_result=0/' ./LCD35-show
fi
echo "About to run LCD35-show"
sudo ./LCD35-show
echo "Done running LCD35-show"
#sudo dpkg -i ./xinput-calibrator_0.7.5-1_armhf.deb
# We also don't want to reboot after running rotate.sh (which we do to create
# /etc/X11/xorg.conf.d/99-calibration.conf)
sed -i 's/^sudo reboot/#sudo reboot/' ./rotate.sh
# In order for the rotate to actually be applied, the rotation needs to change
# from the recorded value. To work around this, we just rotate it 90 degrees and
# then rotate it back. This ensures the rotate.sh 0 actually does something
# instead of just exiting saying that it's already at 0.
sudo ./rotate.sh 90
sudo ./rotate.sh 0
cd
sudo rm -rf LCD-show*

###
# Java
###
# We get the zulu JVM because the default-jdk-headless (openjdk-11) does not
# work on ARMv7. Specifically, attempting to install it with apt result in:
#   Error occurred during initialization of VM
#   Server VM is only supported on ARMv7+ VFP
sudo mkdir -p /opt/jdk/ \
&& cd /opt/jdk \
&& sudo wget -q https://cdn.azul.com/zulu-embedded/bin/zulu8.40.0.178-ca-jdk1.8.0_222-linux_aarch64.tar.gz \
&& sudo tar -xzf zulu8.40.0.178-ca-jdk1.8.0_222-linux_aarch64.tar.gz \
&& sudo update-alternatives --install /usr/bin/java java /opt/jdk/zulu8.40.0.178-ca-jdk1.8.0_222-linux_aarch64/bin/java 8 \
&& sudo update-alternatives --install /usr/bin/javac javac /opt/jdk/zulu8.40.0.178-ca-jdk1.8.0_222-linux_aarch64/bin/javac 8 \
&& sudo rm zulu8.40.0.178-ca-jdk1.8.0_222-linux_aarch64.tar.gz;

sudo update-alternatives --config java
sudo update-alternatives --config javac  # should say there is only one alternative
cd

# Make sure we have the i2c device on next boot
grep i2c_dev /etc/modules || echo i2c_dev | sudo tee -a /etc/modules

###
# OpenHAB
###
curl --fail -s 'https://openhab.jfrog.io/artifactory/api/gpg/key/public' | sudo apt-key add - \
&& echo 'deb https://openhab.jfrog.io/artifactory/openhab-linuxpkg stable main' | sudo tee /etc/apt/sources.list.d/openhab2.list \
&& sudo apt-get update \
&& sudo apt-get install openhab2 \
&& sudo apt-get autoremove -y \
&& sudo /bin/systemctl daemon-reload \
&& sudo /bin/systemctl enable openhab2.service \
&& sudo adduser openhab i2c \
&& sudo adduser openhab gpio \
&& sudo /bin/systemctl start openhab2.service;


###
# Install Hestia
###
sudo rm -rf /home/pi/git \
&& mkdir -p /home/pi/git \
&& cd /home/pi/git/ \
&& git clone --single-branch --branch ONE https://github.com/HestiaPi/hestia-touch-openhab.git \
&& cd /home/pi/git/hestia-touch-openhab/home/pi/ \
&& cp -R scripts /home/pi/ \
&& cd /home/pi/scripts/ \
&& sudo chmod +x updateone.sh \
&& touch /tmp/publicip \
&& sudo chmod 777 /tmp/publicip \
&& sed -i 's/sudo reboot/#sudo reboot/' updateone.sh \
&& sudo ./updateone.sh \
&& sed -i 's/#sudo reboot/sudo reboot/' updateone.sh;
# We don't want to reboot this time, but we do want to reboot in the normal case
###&& sed -i 's/sudo rsync/#sudo rsync/' updateone.sh \
### rsync overwrites openhab 2.5.12 with 2.5.3, so we skip that
cd
sudo rm -rf git  # clean up after ourselves

# Restart the service to pick up the configs updated by updateone.sh
sudo systemctl restart openhab2.service;
# At this point openhab2 should be starting up and will eventually be listening
# on port 8080.  We wait for it to be online before continuting...

count=0
server_is_up=1
curl --fail -s 'http://localhost:8080/' || server_is_up=0
while [ $server_is_up -eq 0 ]; do
	echo "Waiting for server to come online. It's been $count minutes"
	count=$((count+1))
	sleep 60
	server_is_up=1
	curl --fail -s 'http://localhost:8080/' || server_is_up=0
done
echo "Server is now up and running."

# Standard setup
echo "Running setup wizard..."
count=0
failed=1
while [ $failed -eq 1 ]; do
	echo "Attempting to trigger the setup process for the last $count minutes"
	count=$((count+1))
	sleep 60
	failed=0
	curl --fail -s 'http://localhost:8080/start/index?type=standard' || failed=1
done
count=0
failed=1
while [ $failed -eq 1 ]; do
	echo "Checking to see if setup is complete. Elapsed time: $count minutes"
	count=$((count+1))
	sleep 60
	failed=0
	curl --fail -s -H 'Content-Type: application/json' http://localhost:8080/rest/services/org.eclipse.smarthome.i18n/config || failed=1
done
# When the index page includes Paper UI, it's safe to continue
count=0
failed=1
while [ $failed -eq 1 ]; do
	echo "Waiting for server to finish setup. It's been $count minutes"
	count=$((count+1))
	sleep 60
	failed=0
	curl --fail -s http://localhost:8080/start/index | grep "Paper UI" || failed=1
done

echo "Installing exec, http, GPIO & MQTT bindings; Map & Regex transformations"
for binding in binding-exec binding-http1 binding-mqtt binding-gpio1 transformation-map transformation-regex; do
	curl --fail -s -H 'Content-Type: application/json' --data-ascii "{\"id\":\"$binding\"}" "http://localhost:8080/rest/extensions/$binding/install" || failed=1
	while [ $failed -eq 1 ]; do
		failed=0
		# POST to request the binding get installed
		curl --fail -s -H 'Content-Type: application/json' --data-ascii "{\"id\":\"$binding\"}" "http://localhost:8080/rest/extensions/$binding/install" || failed=1
		if [ $failed -eq 1 ]; then
			echo "Request to install $binding failed, will retry in 20 seconds"
			sleep 20  # Give system some time to settle down
		else
			echo "Requested installation of $binding"
		fi
	done
done
# Wait for each of them to show up in the list of installed bindings
for binding in exec http mqtt gpio; do
	count=0
	failed=0
	curl --fail -s "http://localhost:8080/rest/bindings" | grep -q $binding || failed=1
	while [ $failed -eq 1 ]; do
		echo "Waiting for server to finish installing $binding bindings. It's been $count minutes"
		count=$((count+1))
		sleep 60
		failed=0
		curl --fail -s "http://localhost:8080/rest/bindings" | grep -q $binding || failed=1
	done
done
# Wait for each of them to show up in the list of installed transformation
for transformation in transformation-map transformation-regex; do
	count=0
	failed=0
	curl --fail -s "http://localhost:8080/rest/extensions/$transformation" | grep -q '"installed":true' || failed=1
	while [ $failed -eq 1 ]; do
		echo "Waiting for server to finish installing $transformation transformation. It's been $count minutes"
		count=$((count+1))
		sleep 60
		failed=0
		curl --fail -s "http://localhost:8080/rest/extensions/$transformation" | grep -q '"installed":true' || failed=1
	done
done


# Install OpenHAB Cloud Connector
count=0
failed=0
echo "Installing OpenHAB Cloud Connector..."
curl --fail -s -H 'Content-Type: application/json' --data-ascii '{"id":"misc-openhabcloud"}' 'http://localhost:8080/rest/extensions/misc-openhabcloud/install' || failed=1
while [ $failed -eq 1 ]; do
	echo "Waiting for server to finish installing OpenHAB Cloud Connector. It's been $count minutes"
	count=$((count+1))
	sleep 60
	failed=0
	curl --fail -s 'http://localhost:8080/rest/extensions/misc-openhabcloud' | grep -q '"installed":true' || failed=1
done

# The user interfaces installed by default are fine

echo "Disabling script to get the public IP address"
cd ~/scripts
mv getpublicip.sh getpublicip.sh.bak
rm -f /tmp/publicip
echo '#!/bin/sh -e' > getpublicip.sh
chmod +x getpublicip.sh
cd


###
# Turnkey
###
wget -q https://nodejs.org/dist/v8.9.4/node-v8.9.4-linux-armv6l.tar.xz \
&& sudo mkdir -p /usr/lib/nodejs \
&& sudo tar -xJf node-v8.9.4-linux-armv6l.tar.xz -C /usr/lib/nodejs \
&& rm -rf node-v8.9.4-linux-armv6l.tar.xz \
&& sudo mv /usr/lib/nodejs/node-v8.9.4-linux-armv6l /usr/lib/nodejs/node-v8.9.4 \
&& echo 'export NODEJS_HOME=/usr/lib/nodejs/node-v8.9.4' >> ~/.profile \
&& echo 'export PATH=$NODEJS_HOME/bin:$PATH' >> ~/.profile \
&& . ~/.profile \
&& wget -q https://dl.google.com/go/go1.10.linux-armv6l.tar.gz \
&& sudo tar -C /usr/local -xzf go*gz \
&& rm go*gz \
&& echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >>  ~/.profile \
&& echo 'export GOPATH=$HOME/go' >>  ~/.profile \
&& . ~/.profile;

cd /home/pi/scripts \
&& git clone https://github.com/anon8675309/raspberry-pi-turnkey.git \
&& sudo systemctl stop dnsmasq && sudo systemctl stop hostapd \
&& echo 'interface wlan0
static ip_address=192.168.4.1/24' | sudo tee --append /etc/dhcpcd.conf;

sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig \
&& sudo systemctl daemon-reload \
&& sudo systemctl restart dhcpcd \
&& echo 'interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h' | sudo tee --append /etc/dnsmasq.conf \
&& echo 'interface=wlan0
driver=nl80211
ssid=HESTIAPI
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=HESTIAPI
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP' | sudo tee --append /etc/hostapd/hostapd.conf \
&& echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' | sudo tee --append /etc/default/hostapd \
&& sudo rm /lib/systemd/system/hostapd.service \
&& sudo systemctl unmask hostapd
# We remove the hostapd.service file in /lib/systemd/system so systemd will pick up
# the hostapd.service file in /etc/init.d instead
sudo systemctl enable hostapd || true
# Starting hostapd will fail in qemu because there is no wifi card
sudo systemctl start hostapd || true
sudo systemctl start dnsmasq

# Hide the Email address field
sed -i 's/type="email"/type="hidden"/g' raspberry-pi-turnkey/templates/index.html
sed -i 's/\(<label for="inputEmail">Email address<\/label>\)/<!-- \1 -->/g' raspberry-pi-turnkey/templates/index.html
# Hide a bug in Jessie
sed -i 's/checkwpa = True/checkwpa = False;valid_psk=True/' raspberry-pi-turnkey/startup.py
cd


###
# Autostart
###
# We grep for turnkey first and only add the entries if they don't already
# exist.  This allows us to run this script multiple times will not put
# these lines into rc.local multiple times.
grep raspberry-pi-turnkey /etc/rc.local || \
(grep -v "exit 0" /etc/rc.local; echo "su pi -c '/usr/bin/sudo /usr/bin/python3 /home/pi/scripts/raspberry-pi-turnkey/startup.py &'"; echo "su -l pi -c 'sudo xinit /home/pi/scripts/kiosk-xinit.sh'"; echo "exit 0") > rc.local && sudo mv rc.local /etc/rc.local
sudo chmod +x /etc/rc.local

# Patch /home/pi/scripts/kiosk-xinit.sh to display the message about connecting
# to HESTIAPI with your phone for longer so the user will know what they should
# do to complete the setup of their new hestiapi.
if grep -q "sleep 20" /home/pi/scripts/kiosk-xinit.sh; then
	# Change "sleep 20" to...
	# If wifi isn't set up, sleep 500, otherwise sleep 20
	sed -i 's|sleep 20|if grep -q "hostapd" /home/pi/scripts/raspberry-pi-turnkey/status.json; then sleep 500; else sleep 20; fi|g' /home/pi/scripts/kiosk-xinit.sh
fi

###
# Kweb
###
echo "Setting up some extra swap space for kweb"
# This requires more memory than the pi has on Stretch, so we set up swap
sudo dd if=/dev/zero of=/swap1 bs=$((1024*1024)) count=256
sudo chmod 600 /swap1
sudo mkswap /swap1
sudo swapon /swap1

echo "Installing kweb"
cd ~ \
&& wget -q http://steinerdatenbank.de/software/kweb-1.7.9.8.tar.gz \
&& tar -xzf kweb-1.7.9.8.tar.gz \
&& cd kweb-1.7.9.8 \
&& ./debinstall \
&& cd ~ \
&& rm -rf kweb-1.7.9.8 kweb-1.7.9.8.tar.gz;

echo "Turning off extra swap space"
sudo swapoff /swap1
sudo rm /swap1

echo "Removing authorized SSH keys file"
rm ~/.ssh/authorized_keys

# Remove ourselves
rm $0
# Clean up
rm -f $HOME/.bash_history

echo "Setup complete, shutting down"
nohup sudo shutdown -h now >/dev/null 2>/dev/null &
