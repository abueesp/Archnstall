#!/bin/bash

#Fix Arch Automatic A2DP Audio Bluetooth System with Pulseaudio
### Must be run as non-root user

if [ "$SUDO_USER" ]; then
	echo "Must be run as non-root user";
	exit
fi

currentDir=$(cd $(dirname "$0")
  pwd
)
echo "Welcome! This script will help you to fix Arch automatic A2DP audio bluetooth system with Pulseaudio."

AUTOCONNECT="AUTOCONNECT"
while [ $AUTOCONNECT != "y" ] && [ $AUTOCONNECT != "n" ];
do
	read -p "When a bluetooth device connects do you want move audio output to the bluetooth device? y/n : " AUTOCONNECT
done
AUTOENABLE="AUTOENABLE"
while [ $AUTOENABLE != "y" ] && [ $AUTOENABLE != "n" ];
do
	read -p "Do you want the bluetooth device to power on the bluetooth signal automatically? y/n : " AUTOENABLE
done
START_PATH=$currentDir
cd $START_PATH
export START_PATH
#--------------------------------------------------------------------
function tst {
    echo "===> Executing: $*"
    if ! $*; then
        echo "Exiting script due to error from: $*"
        exit 1
    fi
}
#--------------------------------------------------------------------

# Install Pulseaudio & Bluez
tst sudo pacman -S bluez pulseaudio pulseaudio-bluetooth --noconfirm --force

# Install dbus for python
tst sudo pacman -S python-dbus --noconfirm --needed

# Create users and priviliges for Bluez-Pulse Audio interaction - most should already exist
#	tst sudo groupadd --system pulse

ISUSER=$USER
if [ -z "$ISUSER" ]
then
        tst sudo userdel pulse
	tst sudo groupdel pulse-access
	tst sudo groupadd --system pulse-access
        tst sudo useradd --system --gid pulse-access pulse
fi
if [[ "$ISUSER" =~ ^-?[0-9]+$ ]]
then
	tst sudo groupadd --system pulse-access
        tst sudo useradd --system --gid pulse-access pulse
fi

if [[ "$ISUSER" =~ ^-?[0-9]+$ ]]
then
        tst sudo useradd root
fi

if [[ "$ISUSER" =~ ^-?[0-9]+$ ]]
then
        tst sudo useradd lp
fi

if [[ -z "$ISUSER" ]]
then
        tst sudo useradd pulse-access
fi
if [[ "$ISUSER" =~ ^-?[0-9]+$ ]]
then
        tst sudo userdel pulse-access
        tst sudo useradd pulse-access
fi

tst sudo rm /usr/lib/systemd/user/pulseaudio.service
tst sudo touch /usr/lib/systemd/user/pulseaudio.service
tst printf "[Unit]
Description=Sound Service

# We require pulseaudio.socket to be active before starting the daemon, because
# while it is possible to use the service without the socket, it is not clear
# why it would be desirable.
#
# A user installing pulseaudio and doing systemctl --user start pulseaudio
# will not get the socket started, which might be confusing and problematic if
# the server is to be restarted later on, as the client autospawn feature
# might kick in. Also, a start of the socket unit will fail, adding to the
# confusion.
#
# After=pulseaudio.socket is not needed, as it is already implicit in the
# socket-service relationship, see systemd.socket(5).
Requires=pulseaudio.socket
ConditionUser=!root

[Service]
# Note that notify will only work if --daemonize=no
Type=notify
ExecStart=/usr/bin/pulseaudio --daemonize=no
Restart=on-failure

[Install]
Also=pulseaudio.socket
WantedBy=default.target" | sudo tee -a /usr/lib/systemd/user/pulseaudio.service
tst sudo chmod +x /usr/lib/systemd/user/pulseaudio.service
tst systemctl --user enable pulseaudio.service

tst sudo rm /usr/lib/systemd/system/bluetooth.service
tst sudo touch /usr/lib/systemd/system/bluetooth.service
tst printf "[Unit]
Description=Bluetooth service
Documentation=man:bluetoothd(8)
ConditionPathIsDirectory=/sys/class/bluetooth

[Service]
Type=dbus
BusName=org.bluez
ExecStart=/usr/lib/bluetooth/bluetoothd
NotifyAccess=main
#WatchdogSec=10
#Restart=on-failure
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
LimitNPROC=1
ProtectHome=true
ProtectSystem=full

[Install]
WantedBy=bluetooth.target
Alias=dbus-org.bluez.service" | sudo tee -a /usr/lib/systemd/system/bluetooth.service
tst sudo chmod +x /usr/lib/systemd/system/bluetooth.service
tst sudo systemctl enable bluetooth.service

echo "===========Setting Bluetooth Policy========="
if [ $AUTOCONNECT = "y" ]; then
    echo "=====Installing rules for auto-connect bluez-udev====="
    #--------------------------------------------------------------------
    function tst {
        echo "===> Executing: $*"
        if ! $*; then
            echo "Exiting script due to error from: $*"
            exit 1
        fi
    }
    #--------------------------------------------------------------------

    if [ -f /etc/udev/rules.d/99-com.rules ]; then

	printf 'SUBSYSTEM=="input", GROUP="input", MODE="0660"
    + KERNEL=="input[0-9]*", RUN+="/usr/local/bin/bluez-udev"' | sudo tee -a /etc/udev/rules.d/99-com.rules

    else

    tst sudo touch /etc/udev/rules.d/99-com.rules
    tst sudo chmod 666 /etc/udev/rules.d/99-com.rules
    printf 'SUBSYSTEM=="input", GROUP="input", MODE="0660"
    + KERNEL=="input[0-9]*", RUN+="/usr/local/bin/bluez-udev"' | sudo tee -a /etc/udev/rules.d/99-com.rules
    fi

    sudo cp usr/local/bin/bluez-udev /usr/local/bin/bluez-udev
    sudo chmod +x /usr/local/bin/bluez-udev

fi

if [ $AUTOENABLE = "y" ]; then
    echo "=====Power On Bluetooth Automatically -- Enabled ====="
    tst sudo sed -i 's/AutoEnable=.*$/Autoenable=True/g' /etc/bluetooth/main.conf
fi

if [ $AUTOENABLE = "n" ]; then
    echo "=====Power On Bluetooth Automatically -- Disabled ====="
    tst sudo sed -i 's/AutoEnable=.*$/Autoenable=False/g' /etc/bluetooth/main.conf
fi

echo "============Bluetooth Configuration is Complete============="

echo "# Your device should now be set as a pulseaudio sink

# Additionally you won't need to set your bt device as a2dp sink
# This will need to be done manually each time you reconnect your BT device
# Until we create a udev rule to handle this
# Get Card Number
sudo pactl list cards
sudo pactl set-card-profile $CARD_NUMBER a2dp_sink

#You don't need to do this because we are going to include automatically an udev rule for A2DP"

sudo touch /etc/udev/rules.d/20-bt-auto-enable-a2dp.rules
echo 'SUBSYSTEM=="bluetooth", ACTION=="add", RUN+="/home/$USER/.config/bt-auto-enable-a2dp.sh"' | sudo tee -a /etc/udev/rules.d/20-bt-auto-enable-a2dp.rules
rm /home/$USER/.config/bt-auto-enable-a2dp.sh
touch /home/$USER/.config/bt-auto-enable-a2dp.sh
printf '#!/bin/sh
# From: https://gist.github.com/hxss/a3eadb0cc52e58ce7743dff71b92b297
# Dependencies:
# * bluez-tools
# * expect
# * perl

function enable_a2dp() {
	# run connect command in bluetoothctl and wait for resolve of services
	expect <<< "
		spawn bluetoothctl
		send \"connect $mac\r\"
		log_user 0
		expect -re \".*Device $mac ServicesResolved: yes\"
	"
	# enable card in pulseaudio
	pactl set-card-profile $pulsecard a2dp_sink
	logger -p info "mac $mac enabled"
	headsetname=`bt-device -l | perl -ne "/(.*) \("$mac"\)/ and print \"$1\n\""`
	notify-send "Headset connected" "$headsetname" --icon=blueman-headset
}
function search_headsets() {
	sleep 1
	# in all added devices
	for mac in `bt-device -l | perl -ne "/.*\((.*)\)/ and print \"$1\n\""`
	do
		# search for connected device with AudioSink service
		if [[ `bt-device -i $mac | perl -00 -ne "/.*Trusted: 1.*\n\s*Blocked: 0.*\n\s*Connected: 1\n\s*UUIDs: .*AudioSink.*/ and print \"1\n\""` ]]; then
			logger -p info "found mac: $mac"
			# convert mac to pulse card name
			pulsecard=`perl -pe "s/:/_/g" <<< "bluez_card.$mac"`
			enable_a2dp
		fi
	done
	echo "search done"a
}
logger -p info "${BASH_SOURCE[0]}"
# get script owner name
user=`stat -c \%U $0`
if [ "$user" == `whoami` ]; then
	# if script runned by owner - start main function
	search_headsets
elif [ "`w -hs $user`" ]; then
	# else if user session exist(to prevent running on system startup) - run script from user
	machinectl shell --uid=$user .host ${BASH_SOURCE[0]}
fi' | sudo tee -a bt-auto-enable-a2dp.sh
echo "Installing some tools"
tst sudo pacman -S blueman alsa-utils pavucontrol --noconfirm --needed
echo ""
echo "No errors were found"
echo ""
echo "Please reboot your system and  use pavucontrol and blueman-manager to control the audio and bluetooth devices"
