sudo ifconfig #adding container ad-hoc vlan
read -p "Choose your host network interface for creating a new VLAN (wlp1s0 by default): " INTERFACE
INTERFACE="${INTERFACE:=wlp1s0}"
VLANINTERFACE="${INTERFACE:0:2}.tor"
sudo ip link add link $INTERFACE name $VLANINTERFACE type vlan id $(((RANDOM%4094)+1))
sudo ip addr add 10.0.0.1/24 brd 10.0.0.255 dev $VLANINTERFACE
sudo sudo ip link set $VLANINTERFACE up
networkctl
#printf "[Service]
#ExecStart=
#ExecStart=/usr/bin/systemd-nspawn --quiet --boot --keep-unit --link-journal=guest --network-macvlan=$VLANINTERFACE --private-network --directory=$VARCONTAINERS/$TORCONTAINER LimitNOFILE=32768" | sudo tee -a /etc/systemd/system/systemd-nspawn@$TORCONTAINER.service.d/$TORCONTAINER.conf #config file [yes, first empty ExecStart is required]. You can use --ephemeral instead of --keep-unit --link-journal=guest and then you can delete the machine
sudo systemctl daemon-reload
