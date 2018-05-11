
### Questions ### https://www.archlinux.org/feeds/news/ https://wiki.archlinux.org/index.php/IRC_channel (add to weechat) https://www.archlinux.org/feeds/  https://security.archlinux.org/
#DNS (unbound resolv.conf dnssec dyndns) and Firewall
#Awesome Linux
#create encfs alias
#machinectl?  torb yes but torify udp Connection to a local address are denied since it might be a TCP DNS query to a local DNS server. Rejecting it for safety reasons. (in tsocks_connect() at connect.c
#gdb vs strace vs perf trace vs reptyr vs sysdig vs dtrace http://www.brendangregg.com/blog/2015-07-08/choosing-a-linux-tracer.html https://www.slideshare.net/brendangregg/velocity-2015-linux-perf-tools/105
# https://kernelnewbies.org/KernelGlossary https://0xax.gitbooks.io/linux-insides/content/Booting/
#next4 snapper? 
#different results on listpkgsbysize? 
#UsbGuard requires lrelease-qt4 but not on qt4-4.8.7-23, only qt4-4.8.7-24?
#create pkgbuild from deb ^https://wiki.archlinux.org/index.php/Trusted_Users#How_do_I_become_a_TU.3F
#customizerom

### Restoring Windows on Grub2 ###
sudo os-prober 
if [ $? -ne 0 ]
            then
                        sudo grub-mkconfig -o /boot/grub/grub.cfg
            else
                        echo "No Windows installed"
fi

### MAC ### 
echo "Randomize MAC"
printf'
[connection-mac-randomization]
# Randomize MAC for every ethernet connection
ethernet.cloned-mac-address=random
# Generate a random MAC for each WiFi and associate the two permanently.
wifi.cloned-mac-address=stable' | tee -a /etc/NetworkManager/NetworkManager.conf

### Optimize Pacman, Update, Upgrade, Snapshot ###
sudo pacman -Sc --noconfirm && sudo pacman-optimize #Improving pacman database access speeds reduces the time taken in database-related tasks
sudo pacman -Syu --noconfirm #update & upgrade
sudo pacman -S snap-pac --noconfirm --needed #Installing snapper
#sudo snapper -c root create-config / #Create snapshot folder (no chsnap for ext4)
#snapper -c preupgrade create --description preupgrade -c number 1 #Make snapshot preupgrade  (no chsnap for ext4)

### Tor ###
sudo pacman -S arch-install-scripts base arm --noconfirm --needed
sudo pacman -S tor --noconfirm --needed
sudo pacman -S torsocks --noconfirm --needed

#Create user
TORUSER="tor"
sudo useradd -m $TORUSER
sudo passwd $TORUSER

# Run Tor as chroot
sudo find /var/lib/tor/ ! -user tor -exec chown tor:tor {} \;
sudo chown -R tor:tor /var/lib/tor/
sudo chmod -R 755 /var/lib/tor
sudo systemctl --system daemon-reload
export TORCHROOT=/opt/torchroot
sudo mkdir -p $TORCHROOT
sudo mkdir -p $TORCHROOT/etc/tor
sudo mkdir -p $TORCHROOT/dev
sudo mkdir -p $TORCHROOT/usr/bin
sudo mkdir -p $TORCHROOT/usr/lib
sudo mkdir -p $TORCHROOT/usr/share/tor
sudo mkdir -p $TORCHROOT/var/lib
sudo ln -s /usr/lib  $TORCHROOT/lib
sudo cp /etc/hosts           $TORCHROOT/etc/hosts
sudo cp /etc/host.conf       $TORCHROOT/etc/host.conf
sudo cp /etc/localtime       $TORCHROOT/etc/localtime
sudo cp /etc/nsswitch.conf   $TORCHROOT/etc/nsswitch.conf 
sudo cp /etc/resolv.conf     $TORCHROOT/etc/resolv.conf 
sudo cp /etc/tor/torrc       $TORCHROOT/etc/tor/torrc
sudo cp /usr/bin/tor         $TORCHROOT/usr/bin/tor
sudo cp /usr/share/tor/geoip* $TORCHROOT/usr/share/tor/geoip*
sudo cp /lib/libnss* /lib/libnsl* /lib/ld-linux-*.so* /lib/libresolv* /lib/libgcc_s.so* $TORCHROOT/usr/lib/
sudo cp $(ldd /usr/bin/tor | awk '{print $3}'|grep --color=never "^/") $TORCHROOT/usr/lib/
sudo cp -r /var/lib/tor      $TORCHROOT/var/lib/
sudo chown -R tor:tor $TORCHROOT/var/lib/tor
sh -c "grep --color=never ^tor /etc/passwd | sudo tee -a $TORCHROOT/etc/passwd"
sh -c "grep --color=never ^tor /etc/group | sudo tee -a $TORCHROOT/etc/group"
sudo mknod -m 644 $TORCHROOT/dev/random c 1 8
sudo mknod -m 644 $TORCHROOT/dev/urandom c 1 9
sudo mknod -m 666 $TORCHROOT/dev/null c 1 3
if [[ "$(uname -m)" == "x86_64" ]]; then
  sudo cp /usr/lib/ld-linux-x86-64.so* $TORCHROOT/usr/lib/.
  sudo ln -sr /usr/lib64 $TORCHROOT/lib64
  sudo ln -s $TORCHROOT/usr/lib ${TORCHROOT}/usr/lib64
fi
#echo 'alias chtor="sudo chroot --userspec=$TORUSER:$TORUSER /opt/torchroot /usr/bin/tor"' | tee -a .bashrc

# Being able to run tor as a non-root user, and use a port lower than 1024 you can use kernel capabilities. As any upgrade to the tor package will reset the permissions, consider using pacman#Hooks, to automatically set the permissions after upgrades.
sudo setcap CAP_NET_BIND_SERVICE=+eip /usr/bin/tor
echo "[Action]
Description = Ports lower than 1024 available for Tor
Exec = sudo setcap CAP_NET_BIND_SERVICE=+eip /usr/bin/tor" | sudo tee -a /usr/share/libalpm/hooks/tor.hook
TORPORT=$(shuf -i 2000-65000 -n 1)
echo "TORPORT $TORPORT"
TORCONTROLPORT=$(shuf -i 2000-65000 -n 1)
echo "TORCONTROLPORT $TORCONTROLPORT"
TORHASH=$(echo -n $RANDOM | sha256sum)
sudo vim -c ":%s/#SocksPort 9050/SocksPort $TORPORT/g" -c ":wq" /etc/tor/torrc
sudo vim -c ":%s/#ControlPort 9051/#ControlPort $TORCONTROLPORT/g" -c ":wq" /etc/tor/torrc
sudo vim -c ":%s/#HashedControlPassword*$/#HashedControlPassword 16:${HASH:-2}/g" -c ":wq" /etc/tor/torrc
sudo vim -c ":%s/#TorPort 9050/TorPort $TORPORT/g" -c ":wq" /etc/tor/torsocks.conf

# All DNS queries to Tor
TORDNSPORT=$(shuf -i 2000-65000 -n 1)
echo "DNSPort $TORDNSPORT"  | sudo tee -a /etc/tor/torrc 
echo "AutomapHostsOnResolve 1" | sudo tee -a /etc/tor/torrc 
echo "AutomapHostsSuffixes .exit,.onion" | sudo tee -a /etc/tor/torrc
sudo pacman -S dnsmasq --noconfirm --needed
sudo vim -c ":%s|#port=|port=$TORDNSPORT |g" -c ":wq" /etc/dnsmasq.conf
sudo vim -c ":%s|#conf-file=/usr/share/dnsmasq/trust-anchors.conf|conf-file=/usr/share/dnsmasq/trust-anchors.conf|g" -c ":wq" /etc/dnsmasq.conf
sudo vim -c ":%s|#dnssec|dnssec|g" -c ":wq" /etc/dnsmasq.conf
sudo vim -c ":%s|#no-resolv|no-resolv|g" -c ":wq" /etc/dnsmasq.conf
sudo vim -c ":%s|#server=/localnet/192.168.0.1|server=127.0.0.1|g" -c ":wq" /etc/dnsmasq.conf
sudo vim -c ":%s|#listen-address=|listen-address=127.0.0.1|g" -c ":wq" /etc/dnsmasq.conf
sudo vim -c ":%s|#nohook resolv.conf|nohook resolv.conf|g" -c ":wq" /etc/dhcpcd.conf
sudo dnsmasq

# Pacman over Tor
sudo vim -c ':%s|#XferCommand = /usr/bin/curl|XferCommand = /usr/bin/curl --socks5-hostname localhost:$TORPORT -C - -f %u > %o" \n#XferCommand = /usr/bin/curl|g' -c ':wq' /etc/pacman.conf

# Running Tor in a systemd-nspawn container with a virtual network interface [which is more secure than chroot]
TORCONTAINER=tor-exit #creating container and systemd service
SVRCONTAINERS=/srv/container
VARCONTAINERS=/var/lib/container
sudo mkdir $SVRCONTAINERS
sudo mkdir $SVRCONTAINERS/$TORCONTAINER
sudo pacstrap -i -c -d $SVRCONTAINERS/$TORCONTAINER base tor arm --noconfirm --needed
sudo mkdir $VARCONTAINERS
sudo ln -s $SVRCONTAINERS/$TORCONTAINER $VARCONTAINERS/$TORCONTAINER
sudo mkdir /etc/systemd/system/systemd-nspawn@$TORCONTAINER.service.d
sudo ifconfig #adding container ad-hoc vlan
read -p "Write network interface to create VLAN (wlp2s0 by default): " INTERFACE
INTERFACE="${INTERFACE:=wlp2s0}"
VLANINTERFACE="${INTERFACE:0:2}.tor"
sudo ip link add link $INTERFACE name $VLANINTERFACE type vlan id $(((RANDOM%4094)+1))
networkctl
printf "[Service] 
ExecStart=
ExecStart=/usr/bin/systemd-nspawn --quiet --boot --keep-unit --link-journal=guest --network-macvlan=$VLANINTERFACE --private-network --directory=$VARCONTAINERS/$TORCONTAINER LimitNOFILE=32768" | sudo tee -a /etc/systemd/system/systemd-nspawn@tor-exit.service.d/tor-exit.conf #config file [yes, first empty ExecStart is required]. You can use --ephemeral instead of --keep-unit --link-journal=guest and then you can delete the machine
sudo systemctl daemon-reload
TERMINAL=$(echo "$(tty)")
TERM="${TERMINAL:5:4}0"
echo $TERM | sudo tee -a $SVRCONTAINERS/$TORCONTAINER/etc/securetty 
TERM="${TERMINAL:5:4}1"
echo $TERM | sudo tee -a $SVRCONTAINERS/$TORCONTAINER/etc/securetty 
TERM="${TERMINAL:5:4}2"
echo $TERM | sudo tee -a $SVRCONTAINERS/$TORCONTAINER/etc/securetty 
TERM="${TERMINAL:5:4}3"
echo $TERM | sudo tee -a $SVRCONTAINERS/$TORCONTAINER/etc/securetty
TERM="${TERMINAL:5:4}4"
echo $TERM | sudo tee -a $SVRCONTAINERS/$TORCONTAINER/etc/securetty 
TERM="${TERMINAL:5:4}5"
echo $TERM | sudo tee -a $SVRCONTAINERS/$TORCONTAINER/etc/securetty

# Checking conf
sudo cp -r $TORCHROOT/var/lib/ /var/lib/tor
sudo chown -R tor:tor $TORCHROOT/var/lib/tor
sudo cp /etc/tor/torrc $TORCHROOT/etc/tor/torrc
sudo cp /etc/dnsmasq.conf $TORCHROOT/etc/dnsmasq
sudo cp /etc/dhcpcd.conf $TORCHROOT/etc/dhcpcd.conf
sudo cp /etc/pacman.conf $TORCHROOT/etc/pacman.conf

sudo systemctl daemon-reload
systemctl start systemd-nspawn@tor-exit.service
machinectl -a
machinectl login tor-exit #ctrl shift ]
networkctl
machine enable $TORCONTAINER #enable at boot

### Shadowsocks & GPG ###
sudo pacman -S shadowsocks-qt5 shadowsocks --noconfirm --needed
sudo pacman -S gnupg gnupg2 --noconfirm --needed

### Security ###
# Password management
#sudo authconfig --passalgo=sha512 --update #pass sha512 $6 by default 
#sudo chage -d 0 tiwary #To force new password in next login, but unnecessary as we are going to renew it now
sudo pacman -S libpwquality --noconfirm --needed
##########Activate password requirements (Activate password required pam_cracklib.so retry=2 minlen=10 difok=6 dcredit=-1 ucredit=-1 ocredit=-1 lcredit=-1 and password required pam_unix.so use_authtok sha512 shadow and deactivate password required pam_unix.so sha512 shadow nullok)
#sudo vim -c ":%1,2s/#password/password" -c ":wq" /etc/pam.d/passwd 
#sudo vim -c ":%3s/password/#password" -c ":wq" /etc/pam.d/passwd
echo "auth optional pam_faildelay.so delay=1" | sudo tee -a /etc/pam.d/system-login #Increase delay in case of failed password (in this case, decreased, time in ms)
echo "auth required pam_tally2.so deny=3 unlock_time=5 root_unlock_time=15 onerr=succeed" | sudo tee -a /etc/pam.d/system-login #Lockout user after three failed login attempts (pam_tally is deprecated and superseded by pam_tally2, time in ms
echo "account required pam_tally2.so" | sudo tee -a /etc/pam.d/system-login
sudo vim -c ":%s/auth       required   pam_tally.so/#auth       required   pam_tally.so/g" -c ":wq" /etc/pam.d/system-login
#echo "MENU MASTER PASSWD $syspass" | sudo tee -a syslinux.cfg #Syslinux bootloader security master password
# TAKE BETWEEN root: AND : FROM $(sudo cat /etc/shadow | grep root)
#https://wiki.archlinux.org/index.php/GRUB/Tips_and_tricks#Password_protection_of_GRUB_menu
sudo chage -M -1 365 $USER #force to change password every 90 days (-M, -W only for warning) but without password expiration (-1, -I will set a different days for password expiration, and -E a data where account will be locked)
sudo chage -W 90 $USER #Warning days for password changing
pwmake 512 #Create a secure 512 bits password
chage -l $USER #Change password
#BIOS lock down
echo " >>>>>> Please lock down your BIOS <<<<< " 

# Avoid fork bombs
sudo vim -c ":%s/#@faculty        soft    nproc           20/@faculty        soft    nproc           1000/g" -c ":wq" /etc/security/limits.conf
sudo vim -c ":%s/#@faculty        hard    nproc           50/@faculty        hard    nproc           2000/g" -c ":wq" /etc/security/limits.conf

#Disable ICMP
echo "Check function disableremoteping"

# Prevent sudo from SFTP: 
echo "auth   required   /lib/security/pam_listfile.so   item=user sense=deny file=/etc/vsftpd.ftpusers onerr=succeed" | sudo tee -a /etc/pam.d/vsftpd
#Similar line can be added to the PAM configuration files, such as /etc/pam.d/pop and /etc/pam.d/imap for mail clients, or /etc/pam.d/sshd for SSH clients.

# TCP Wrappers
echo "Hello. All activity on this server is logged. Inappropriate uses and access will result in defensive counter-actions." | sudo tee -a /etc/banners/sshd
echo "ALL : ALL : spawn /bin/echo `date` %c %d >> /var/log/intruder_alert" | sudo tee -a /etc/hosts.deny ##log any connection attempt from any IP and send the date to intruder_alert logfile
echo "in.telnetd : ALL : severity emerg" | sudo tee -a /etc/hosts.deny ##log any attempt to connect to in.telnetd posting emergency log messages directly to the console

# Encrypt disk to avoid init=/bin/sh

# Encryption of filesystems 
sudo pacman -S encfs pam_encfs --noconfirm --needed #Check https://wiki.archlinux.org/index.php/Disk_encryption#Comparison_table

# Kernel hardening
sudo pacman -S linux-hardened --needed --noconfig
echo "kernel.dmesg_restrict = 1" | sudo tee -a /etc/sysctl.d/50-dmesg-restrict.conf #Restricting access to kernel logs
echo "kernel.kptr_restrict = 1" | sudo tee -a /etc/sysctl.d/50-kptr-restrict.conf #Restricting access to kernel pointers in the proc filesystem

# Sandbox tools
sudo pacman -S firejail --noconfirm --needed
sudo pacman -S bubblewrap --noconfirm --needed
sudo pacman -S lxc arch-install-scripts --noconfirm --needed

# Bluetooth
sudo vi /etc/bluetooth/main.conf -c ':%s|#AutoEnable=false|AutoEnable=false|g' -c ':wq'
sudo rfkill block bluetooth

# USBGuard and USB readonly (previous checker -noexec and --rw included on alias monta)
#git clone https://aur.archlinux.org/usbguard.git
#cd usbguard
#git clone git://github.com/ClusterLabs/libqb.git #dependencies
#cd libqb
#./autogen.sh
#./configure
#make
#sudo make install
#sudo pacman -S libsodium libgcrypt asciidoctor protobuf libseccomp libcap-ng qt4 --noconfirm --needed
#cd ..
#gpg2 --keyserver hkp://pgp.mit.edu --recv-keys AA06120530AE0466
#makepkg -si --nodeps --noconfirm --needed
#gpg2 --delete-secret-and-public-keys --batch --yes AA06120530AE0466
#cd ..
#sudo rm -r usbguard
echo 'SUBSYSTEM=="block",ATTRS{removable}=="1",RUN{program}="/sbin/blockdev --setro %N"' | sudo tee -a  /etc/udev/rules.d/80-readonly-removables.rules
sudo udevadm trigger
sudo udevadm control --reload

# Log out virtual /dev/tty consoles out after 10s inactivity and prevent sudo from X11
echo "export TMOUT=\"\$(( 60*10 ))\"; #to exclude X11 from this rule, delete export word
[ -z \"\$DISPLAY\" ] && export TMOUT;
case \$( /usr/bin/tty ) in
	/dev/tty[0-9]*) export TMOUT;;
esac" | sudo tee -a /etc/profile.d/shell-timeout.sh
echo 'Section "ServerFlags"
    Option "DontVTSwitch" "True"
EndSection' | sudo tee -a /usr/share/X11/xorg.conf.d/ 50-notsudo.conf

# Extra recommendations
echo ">>> Do not use rlogin, rsh, and telnet <<<"
echo ">>> Take care of securing sftp, auth, nfs, rpc, postfix, samba and sql https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Security_Guide/sec-Securing_Services.html <<<"
echo ">>> Take care of securing Docker https://wiki.archlinux.org/index.php/Docker#Insecure_registries https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_atomic_host/7/html-single/getting_started_with_containers/ <<<"


### Network ###
# SSH
if [ -s /etc/ssh/sshd_config ]
then
    echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config
    echo "Protocol 2" | sudo tee -a /etc/ssh/sshd_config
    echo "MaxAuthTries 3" | sudo tee -a etc/ssh/sshd_config
else
    sudo vi /etc/ssh/sshd_config -c ':%s/PermitRootLogin without password/PermitRootLogin no/g' -c ':wq'
    sudo vi /etc/ssh/sshd_config -c ':%s/Protocol 2,1/Protocol 2/g' -c ':wq'
    sudo vi /etc/ssh/sshd_config -c ":%s|MaxAuthTries 6|MaxAuthTries 3|g" -c ":wq" 

fi

# SSHguard (prefered over Fail2ban)
sudo pacman -S sshguard --noconfirm --needed
sudo vim -c ":%s|BLACKLIST_FILE=120:/var/db/sshguard/blacklist.db|BLACKLIST_FILE=50:/var/db/sshguard/blacklist.db|g" -c ":wq" /etc/sshguard.conf #Danger level: 5 failed logins -> banned
sudo vim -c ":%s|THRESHOLD=30|THRESHOLD=10|g" -c ":wq"  /etc/sshguard.conf 
sudo systemctl enable --now sshguard.service

# OpenSSL and NSS
sudo pacman -S openssl nss --noconfirm --needed
cat $(locate ca-certificates) #check all certificates
#blacklist ssl symanteccertificate
wget https://crt.sh/?d=19538258 
sudo mv index.html?d=19538258 /etc/ca-certificates/trust-source/blacklist/19538258-Symantec.crt  #Blacklist Symantec SSL Cert
sudo update-ca-trust

# Suricata IDS/IPS (prefered over Snort https://www.aldeid.com/wiki/Suricata-vs-snort)
gpg2 --keyserver hkp://pgp.mit.edu --recv-keys 801C7171DAC74A6D3A61ED81F7F9B0A300C1B70D
git clone https://aur.archlinux.org/suricata.git
cd suricata
makepkg -si --noconfirm
cd ..
sudo rm -r suricata
gpg2 --delete-secret-and-public-keys --batch --yes 801C7171DAC74A6D3A61ED81F7F9B0A300C1B70D
#sudo vim /etc/suricata/suricata.yaml -c ":%s|HOME_NET: \"[192.168.0.0/16,10.0.0.0/8,172.16.0.0/12]\"|HOME_NET: \"[$myip]\"|g" -c ":wq"
sudo vim -c ":%s|# -|-|g" -c ":wq" /etc/suricata/suricata.yaml #activate rules
suricatasslrule(){ #blacklistsslcertificates
wget https://sslbl.abuse.ch/blacklist/$SSLRULES 
sudo mv $SSLRULES /etc/suricata/rules/$SSLRULES
wget https://sslbl.abuse.ch/blacklist/$SSLRULES_aggressive.rules
sudo mv https://sslbl.abuse.ch/blacklist/$SSLRULES_aggressive.rules -O /etc/suricata/rules/$SSLRULES_aggressive.rules
echo " - $SSLRULES    # available in suricata sources under rules dir" | sudo tee /etc/suricata/suricata.yaml #activate ssl blacklist rules
#echo " - $SSLRULES_aggresive.rules    # available in suricata sources under rules dir" | sudo tee /etc/suricata/suricata.yaml #activate ssl aggressive blacklist
#notice that aggresive rules are not activated
}
SSLRULES=sslblacklist.rules
suricatasslrule
SSLRULES=sslipblacklist.rules
suricatasslrule
SSLRULES=dyre_sslblacklist.rules
suricatasslrule
SSLRULES=dyre_sslipblacklist.rules
suricatasslrule
sudo suricata -c /etc/suricata/suricata.yaml -s signatures.rules -i $INTERFACE -D #start suricata and enable interfaces
echo "[Unit]
Description=Suricata Intrusion Detection Service listening on '%I'
After=network.target
 
[Service]
Type=forking
ExecStart=/usr/bin/suricata -c /etc/suricata/suricata.yaml -i %i -D
ExecReload=/bin/kill -HUP $MAINPID
 
[Install]
WantedBy=multi-user.target" | sudo tee -a /usr/lib/systemd/system/suricata@$INTERFACE.service
sudo systemctl enable --now suricata@$INTERFACE.service

echo "[Unit]
Description=Suricata Intrusion Detection Service listening on '%I'
After=network.target
 
[Service]
Type=forking
ExecStart=/usr/bin/suricata -c /etc/suricata/suricata.yaml -i %i -D
ExecReload=/bin/kill -HUP $MAINPID
 
[Install]
WantedBy=multi-user.target" | sudo tee -a /usr/lib/systemd/system/suricata@$VLANINTERFACE.service
sudo systemctl enable --now suricata@$VLANINTERFACE.service

# Ports
read -p "At this point you should decide what ports you want to open to incoming connections, which are handled by the TCP and UDP chains. For example to open connections for a web server add, without commas: 80 web, 443 https, 22 ssh, 5353 chrome, $TORPORT tor... by default 443 and all of them udp and tcp): " ports
nameofvar="ports"
ports="${ports:=443}"

# Iptables
sudo pacman -S iptables gufw --noconfirm --needed
sudo iptables -F
sudo iptables -A INPUT -i lo -j ACCEPT
for i in $ipports; do
	sudo iptables -A INPUT -p tcp --dport $i
done
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -P INPUT DROP
sudo iptables -P OUTPUT ACCEPT ##If you are a server change this to DROP OUTPUT connections by default too
sudo iptables -P FORWARD DROP
sudo iptables restart

# Avahi daemon
#sudo service avahi-daemon stop #avahi-daemon

# No cups
sudo cupsctl -E --no-remote-any
sudo service cups-browsed stop
sudo systemctl cupsd
sudo systemctl disable org.cups.cupsd

#Nftables
sudo pacman -S nftables --noconfirm --needed
nftports=$(echo "$ports" | tr '\n' ' ' | sed -e 's/[^0-9]/ /g' -e 's/^ *//g' -e 's/ *$//g' | tr -s ' ' | sed 's/ /\n/g')
for i in $nftports; do
	nft add rule inet filter TCP tcp dport $i accept
done
printf "flush ruleset
table inet filter {
        chain input {
                type filter hook input priority 0;

                # accept any localhost traffic
                iif lo accept

                # accept traffic originated from us
                ct state established,related accept

                # activate the following line to accept common local services
                #tcp dport { 22, 80, 443 } ct state new accept

                # accept neighbour discovery otherwise IPv6 connectivity breaks.
                ip6 nexthdr icmpv6 icmpv6 type { nd-neighbor-solicit,  nd-router-advert, nd-neighbor-advert } accept

                # count and drop any other traffic
                counter drop
        }
}" | sudo tee -a /etc/nftables.conf #other examples https://wiki.archlinux.org/index.php/Nftables#Examples
sudo nft flush ruleset #Flush the current ruleset:
sudo nft add table inet filter #Add a table:
#Add the input, forward, and output base chains. The policy for input and forward will be to drop. The policy for output will be to accept.
sudo nft add chain inet filter input { type filter hook input priority 0 \; policy drop \; }
sudo nft add chain inet filter forward { type filter hook forward priority 0 \; policy drop \; }
sudo nft add chain inet filter output { type filter hook output priority 0 \; policy accept \; }
#Add two regular chains that will be associated with tcp and udp:
sudo nft add chain inet filter TCP
sudo nft add chain inet filter UDP
sudo nft add rule inet filter input ct state related,established accept #Related and established traffic will be accepted:
sudo nft add rule inet filter input iif lo accept #All loopback interface traffic will be accepted:
sudo add rule inet filter input ct state invalid drop #Drop any invalid traffic:
sudo add rule inet filter input ip protocol icmp icmp type echo-request ct state new accept #New echo requests (pings) will be accepted:
sudo add rule inet filter input ip protocol udp ct state new jump UDP #New upd traffic will jump to the UDP chain:
sudo add rule inet filter input ip protocol tcp tcp flags \& \(fin\|syn\|rst\|ack\) == syn ct state new jump TCP #New tcp traffic will jump to the TCP chain:
#Reject all traffic that was not processed by other rules:
sudo add rule inet filter input ip protocol udp reject
sudo add rule inet filter input ip protocol tcp reject with tcp reset
sudo add rule inet filter input counter reject with icmp type prot-unreachable

# Rootkit checking and Audits (see at the EOF)

# Antivirus and Cleaners
sudo pacman -S clamav bleachbit --noconfirm --needed


### Tweaks ###
# .bashrc
mv ~/.bashrc ~/.previous-bashrc
wget https://raw.githubusercontent.com/abueesp/Scriptnstall/master/.bashrc

# Snapshots configuration (no chsnap for ext4)
#snapper -c original create --description original #Make snapshot original
#printf 'TIMELINE_MIN_AGE="1800"
#TIMELINE_LIMIT_HOURLY="0"
#TIMELINE_LIMIT_DAILY="0"
#TIMELINE_LIMIT_WEEKLY="0"
#TIMELINE_LIMIT_MONTHLY="6"
#TIMELINE_LIMIT_YEARLY="0"' >> /etc/snapper/configs/mysnapshots
#git clone https://aur.archlinux.org/grub-btrfs.git #Snapshots on grub
#cd grub-btrfs
#makepkg -si --noconfirm
#cd ..
#sudo rm -r grub-btrfs
#git clone https://aur.archlinux.org/packages/snap-pac-grub/
#cd snap-pac-grub
#gpg2 --keyserver hkp://keys.gnupg.net --recv EB4F9E5A60D32232BB52150C12C87A28FEAC6B20
#makepkg -si --noconfirm
#gpg2 --batch --delete-key EB4F9E5A60D32232BB52150C12C87A28FEAC6B20
#cd ..
#sudo rm -r snap-pac-grub

# Pacman tools
sudo pacman -S arch-audit pacgraph pacutils --noconfirm --needed 

# PKGtools
wget https://raw.githubusercontent.com/graysky2/lostfiles/master/lostfiles #Script that identifies files not owned and not created by any Arch Linux package.
sudo mv lostfiles /usr/bin/lostfiles
git clone https://github.com/Daenyth/pkgtools #newpkg - spec2arch - pkgconflict - whoneeds - pkgclean - maintpkg - pip2arch
cd pkgtools/scripts/pip2arch
wget https://raw.githubusercontent.com/lclarkmichalek/pip2arch/master/pip2arch.py
cd ..
cd ..
sudo make install 
cd ..
sudo rm -r pkgtools
bupkgs(){
for i in $( pacman -Qq ); do
	bacman $i
done
}
#alias checkpkgs='pacman -Qq | sudo paccheck --sha256sum --quiet'
#alias listpkgsbysize='pacgraph -c && expac -H M '%m\t%n' | sort -h && echo \"ONLY INSTALLED (NO BASE OR BASE-DEVEL)\" && expac -H M \"%011m\t%-20n\t%10d\" \$(comm -23 <(pacman -Qqen | sort) <(pacman -Qqg base base-devel | sort)) | sort -n'
#alias listpkgsbysize='expac --timefmt='%Y-%m-%d %T' '%l\t%n' | sort && echo \"ONLY INSTALLED (NO BASE OR BASE-DEVEL)\" && expac -HM \"%-20n\t%10d\" \$(comm -23 <(pacman -Qqt | sort) <(pacman -Qqg base base-devel | sort))'
#alias pacmansheet='firefox --new-tab https://wiki.archlinux.org/index.php/Pacman/Rosetta --new-tab https://wiki.archlinux.org/index.php/Pacman/Tips_and_tricks'
#alias purgearchrepo='echo "aurman --stats && read -p \"Name of repo: \" REPO && paclist \$REPO && sudo pacman -Rnsc \$(pacman -Sl \$REPO | grep \"\[installed\]\" | cut -f2 -d\' \")"'
#alias kalifyarch='printf "[archstrike] \n Server = https://mirror.archstrike.org/\$arch/\$repo/ " | sudo tee -a /etc/pacman.conf && sudo pacman-key --recv-keys 9D5F1C051D146843CDA4858BDE64825E7CBC0D51 && sudo pacman-key --finger 9D5F1C051D146843CDA4858BDE64825E7CBC0D51 && sudo pacman-key --lsign-key 9D5F1C051D146843CDA4858BDE64825E7CBC0D51'
#alias haskellfyarch='printf "[haskell-core] \n Server = http://xsounds.org/~haskell/core/\$arch " | sudo tee -a /etc/pacman.conf && sudo pacman-key --recv-keys F3104992EBF24EB872B97B9C32B0B4534209170B && sudo pacman-key --finger F3104992EBF24EB872B97B9C32B0B4534209170B && sudo pacman-key --lsign-key F3104992EBF24EB872B97B9C32B0B4534209170B && Haskwell WAIs: Yesod Framework brings Wrap Server. It is better than Happstack. For small projects try Scotty that also comes with Wrap, or maybe Snaps snaplets"'
#alias rubifyarch='printf "[quarry] \n Server = https://pkgbuild.com/~anatolik/quarry/x86_64/ " | sudo tee -a /etc/pacman.conf && echo "This repo has not key!"'

# AUR-helpers and repositories
sudo pacman -S yaourt --noconfirm --needed 
git clone https://aur.archlinux.org/aurman.git #https://wiki.archlinux.org/index.php/AUR_helpers
cd aurman
makepkg -si --noconfirm
cd ..
sudo rm -r aurman
sudo pacman -S downgrader --noconfirm --needed

# Search tools
sudo pacman -S mlocate recoll the_silver_searcher --noconfirm --needed #find locate
yaourt -S tag-ag --noconfirm 
printf 'tag() { 
command tag "$@"
source /tmp/tag_aliases}
alias ag=tag' | tee -a ~/.bashrc
if [ ! -f /home/$USER/.recoll/recoll.conf ]; then
    mkdir /home/$USER/.recoll
    cp /usr/share/recoll/examples/recoll.conf /home/$USER/.recoll/recoll.conf
fi
vim -c ":%s|topdirs = / ~|topdirs = / ~|g" -c ":wq" /home/$USER/.recoll/recoll.conf
sudo updatedb

# Dock conf
dconf write /com/deepin/dde/dock/docked-apps "['/S@deepin-toggle-desktop', '/S@dde-file-manager', '/S@deepin-music', '/S@chromium', '/S@deepin-screen-recorder', '/S@deepin-voice-recorder', '/S@deepin-system-monitor', '/S@gnome-calculator', '/S@recoll']"

# Deepin conf
dconf write /com/deepin/dde/touchpad/horiz-scroll-enabled "false"
dconf write /com/deepin/dde/mouse/locate-pointer "false"
dconf write /com/deepin/dde/desktop/show-computer-icon "true"
dconf write /com/deepin/dde/desktop/show-home-icon "true"
dconf write /com/deepin/dde/desktop/show-trash-icon "true"
dconf write /com/deepin/dde/daemon/calltrace "true"
dconf write /com/deepin/dde/daemon/debug "true"
dconf write /com/deepin/dde/audio/auto-switch-port "true"
dconf write /com/deepin/dde/sound-effect/camera-shutter "false" #Less sounds
dconf write /com/deepin/dde/sound-effect/desktop-login "false"
dconf write /com/deepin/dde/sound-effect/enabled "false"
dconf write /com/deepin/dde/sound-effect/dialog-error "false"
dconf write /com/deepin/dde/sound-effect/dialog-error-serious "false"
dconf write /com/deepin/dde/sound-effect/dialog-error-critical "false"
dconf write /com/deepin/dde/sound-effect/suspend-resume "false"

# Sound
aurman -S indicator-sound-switcher --noconfirm --needed --noedit
amixer sset Master unmute
amixer cset numid=11,iface=MIXER,name='Capture Switch' off

# Fixing bugs
sudo pacman -S deepin-api --noconfirm -needed

### Virtualbox ###
pacman -Si linux
sudo pacman -S linux-headers
sudo pacman -S virtualbox-host-modules-arch qt4 virtualbox virtualbox-guest-iso --noconfirm --needed
sudo modprobe -a vboxdrv vboxnetflt vboxpci vboxnetadp
sudo /sbin/rcvboxdrv -h
sudo gpasswd -a $USER vboxusers
echo "vboxdrv" | sudo tee -a /etc/modules-load.d/virtualbox.conf
echo "vboxnetadp" | sudo tee -a /etc/modules-load.d/virtualbox.conf
echo "vboxnetflt" | sudo tee -a /etc/modules-load.d/virtualbox.conf
echo "vboxpci" | sudo tee -a /etc/modules-load.d/virtualbox.conf


version=$(vboxmanage -v)
echo $version
var1=$(echo $version | cut -d 'r' -f 1)
echo $var1
var2=$(echo $version | cut -d 'r' -f 2)
echo $var2
file="Oracle_VM_VirtualBox_Extension_Pack-$var1.vbox-extpack"
echo $file
wget http://download.virtualbox.org/virtualbox/$var1/$file -O $file
sudo VBoxManage extpack install $file --replace
sudo rm $file
sudo pacman -S dkms vagrant --noconfirm --needed
vagrant plugin install vagrant-vbguest
wget http://download.virtualbox.org/virtualbox/$var1/VBoxGuestAdditions_$var1.iso
sudo mv VBoxGuestAdditions_$var1.iso /usr/share/VBoxGuestAdditions_$var1.iso
echo "To insert iso additions, install a vm named 'myvm' and move the .iso to your user folder"
virtualbox
vboxmanage storageattach myvm --storagectl IDE --port 0 --device 0 --type dvddrive --medium "/home/$USER/VBox**.iso"


### Emacs ###
sudo pacman -S emacs --noconfirm --needed
sudo pacman -S git --noconfirm --needed
git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d
cd ~/.emacs.d
git clone https://github.com/EnigmaCurry/emacs/find/ancient-history
wget https://github.com/ethereum/emacs-solidity/blob/master/solidity-mode.el
echo 'Carga los elementos de emacs con (add-to-list load-path "~/.emacs.d/") + (load "myplugin.el")' >> README
cd ..


### Vim ###
sudo pacman -S vim --noconfirm --needed
sudo pacman -S git --noconfirm --needed
git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime
sh ~/.vim_runtime/install_awesome_vimrc.sh

if [ -e "/home/$USER/.vim_runtime/vimrcs/basic.vim" ];
	then
		VIMRC=/home/$USER/.vim_runtime/vimrcs/basic.vim
	else
		VIMRC=.vimrc
fi

echo ' ' | tee -a $VIMRC
echo '\" => Commands' | tee -a $VIMRC
echo ":nnoremap <C-B> <C-V>" | tee -a $VIMRC
echo ":nnoremap <C-O> o<Esc>" | tee -a $VIMRC
echo ":command! Vb exe \"norm! \\<C-V>" | tee -a $VIMRC
echo "set autoindent" | tee -a $VIMRC
echo "set paste" | tee -a $VIMRC
echo "set mouse=a" | tee -a $VIMRC

echo ' ' | tee -a $VIMRC
echo '\" => Arrow keys' | tee -a $VIMRC
echo "nnoremap <silent> <ESC>OA <UP>" | tee -a $VIMRC
echo "nnoremap <silent> <ESC>OB <DOWN>" | tee -a $VIMRC
echo "nnoremap <silent> <ESC>OC <RIGHT>" | tee -a $VIMRC
echo "nnoremap <silent> <ESC>OD <LEFT>" | tee -a $VIMRC
echo "inoremap <silent> <ESC>OA <UP>" | tee -a $VIMRC
echo "inoremap <silent> <ESC>OB <DOWN>" | tee -a $VIMRC
echo "inoremap <silent> <ESC>OC <RIGHT>" | tee -a $VIMRC
echo "inoremap <silent> <ESC>OD <LEFT>" | tee -a $VIMRC

echo ' ' | tee -a $VIMRC
echo '\" => Ctrl+Shift+c/p to copy/paste outside vim' | tee -a $VIMRC
echo "nnoremap <C-S-c> +y" | tee -a $VIMRC
echo "vnoremap <C-S-c> +y" | tee -a $VIMRC
echo "nnoremap <C-S-p> +gP" | tee -a $VIMRC
echo "vnoremap <C-S-p> +gP" | tee -a $VIMRC

echo ' ' | tee -a $VIMRC
echo '\" => Macros' | tee -a $VIMRC
function sendtovimrc(){
echo "let @$key='$VIMINSTRUCTION'" | tee -a $VIMRC
#please note the double set of quotes
}
key="i"
VIMINSTRUCTION="isudo pacman -S  --noconfirm --needed\<esc>4bhi"
sendtovimrc

#ag on Ack plugin
printf "if executable('ag')
  let g:ackprg = 'ag --vimgrep'
  :cnoreabbrev ag Ack
endif"  | tee -a $VIMRC

#PATHOGENFOLDER="~/.vim/build"
#mkdir $PATHOGENFOLDER
PATHOGENFOLDER="~/.vim_runtime/sources_forked"
echo "PATHOGENFOLDER=$PATHOGENFOLDER" | tee -a .bashrc
echo 'alias pathogen="read -p \"Name of the plugin: \" PLUGINNAME && read -p \"Plugin Git link: \" PLUGINGIT && git clone $PLUGINGIT $PATHOGENFOLDER/$PLUGINNAME"' | tee -a .bashrc
echo 'alias installvimplugin="pathogen"' | tee -a .bashrc

git clone https://github.com/tpope/vim-sensible $PATHOGENFOLDER/vim-sensible
git clone https://github.com/ocaml/merlin $PATHOGENFOLDER/merlin
git clone https://github.com/OmniSharp/omnisharp-vim $PATHOGENFOLDER/omnisharp-vim && cd $PATHOGENFOLDER/omnisharp-vim && git submodule update --init --recursive && cd server && xbuild && cd
#git clone https://github.com/rhysd/vim-crystal/ $PATHOGENFOLDER/vim-crystal
#git clone https://github.com/venantius/vim-eastwood.git $PATHOGENFOLDER/vim-eastwood
git clone https://github.com/rust-lang/rust.vim $PATHOGENFOLDER/rust
git clone https://github.com/kballard/vim-swift.git $PATHOGENFOLDER/swift
git clone --recursive https://github.com/python-mode/python-mode $PATHOGENFOLDER/python-mode
git clone https://github.com/eagletmt/ghcmod-vim $PATHOGENFOLDER/ghcmod-vim
git clone https://github.com/eagletmt/neco-ghc $PATHOGENFOLDER/neco-ghc
git clone https://github.com/ahw/vim-hooks
echo ":nnoremap gh :StartExecutingHooks<cr>:ExecuteHookFiles BufWritePost<cr>:StopExecutingHooks<cr>" | sudo tee -a /usr/share/vim/vimrc
echo ":noremap ghl :StartExecutingHooks<cr>:ExecuteHookFiles VimLeave<cr>:StopExecutingHooks<cr>" | sudo tee -a /usr/share/vim/vimrc
https://github.com/sheerun/vim-polyglot
echo "syntax on" | sudo tee -a /usr/share/vim/vimrc
git clone https://github.com/scrooloose/nerdcommenter $PATHOGENFOLDER/nerdcommenter
git clone https://github.com/Shougo/neocomplcache.vim $PATHOGENFOLDER/neocomplcache
echo "let g:neocomplcache_enable_at_startup = 1" | tee -a $VIMRC
git clone https://github.com/easymotion/vim-easymotion $PATHOGENFOLDER/vim-easymotion
git clone https://github.com/spf13/PIV $PATHOGENFOLDER/PIV
git clone https://github.com/tpope/vim-surround $PATHOGENFOLDER/vim-surround

mkdir -p /home/nudo/~/.vim_runtime/sources_forked/vim-snippets/snippets
cd /home/nudo/~/.vim_runtime/sources_forked/vim-snippets/snippets
git clone https://github.com/Chalarangelo/30-seconds-of-code/tree/master/test
mv test 30secJavaScript
cd 30secJavaScript
mv {.*}.js {.*}.snippets
cd ..
git clone  https://github.com/kriadmin/30-seconds-of-python-code/tree/3b9790bd73f80afc4af2de1c4fc8f4b5bb5fda45/test
mv test 30secPython3
cd 30secPython3
mv {.*}.py {.*}.snippets
cd

git clone https://github.com/maralla/completor.vim $PATHOGENFOLDER/completor
sudo -H pip install jedi #completor for python
echo "let g:completor_python_binary = '/usr/lib/python*/site-packages/jedi'" | tee -a $VIMRC
cargo install racer #completor for rust
echo "let g:completor_racer_binary = '/usr/bin/racer'" | tee -a $VIMRC
git clone https://github.com/ternjs/tern_for_vim $PATHOGENFOLDER/tern_for_vim
echo "let g:completor_node_binary = '/usr/bin/node'" | tee -a $VIMRC
echo "let g:completor_clang_binary = '/usr/bin/clang'" | tee -a $VIMRC #c++
git clone https://github.com/nsf/gocode $PATHOGENFOLDER/completor #go
echo "let g:completor_gocode_binary = ' $PATHOGENFOLDER/gocode'"
git clone https://github.com/maralla/completor-swift $PATHOGENFOLDER/completor-swift #swift
cd $PATHOGENFOLDER/completor-swift
make
cd
echo "let g:completor_swift_binary = '$PATHOGENFOLDER/completor-swift'" | tee -a $VIMRC

#Vim portability for ssh (sshrc)
wget https://raw.githubusercontent.com/Russell91/sshrc/master/sshrc && sudo chmod -R 600 sshrc && chmod +x sshrc && sudo mv sshrc /usr/local/bin

vimfunctions(){
echo "### Tools ###"    
echo "ack: Search tool, :grep=:ack=:ag :grepadd=:ackadd, :lgrep=LAck, and :lgrepadd=:LAckAdd (see all options with :ack ?)"
echo "bufexplorer: See and manage the current buffers(,o)"
echo "mru: Recently open files (,f)"
echo "ctrlp: Find file or a buffer(,j or c-f)" 
echo "Nerdtree and openfile under cursor: Treemaps (,nn toggle and ,nb bookmark and ,nf find, gf go open file under cursor)"
echo "Goyo.vim and vim-zenroom2: Removes all the distractions (,z)"
echo ":w (,w)"
echo "vim-easymotion: go to (<leader><leader> or //)"
echo "vim-yankstack: Maintains a history of previous yanks :yanks :registers (meta-p, meta-shift-p)"
echo "vim-multiple-cursors: Select multiple cursors (c-n next and c-p previous and c-x skip)"
echo "vim-fugitive: Git wrapper (:Gbrowse and :Gstatus and - for reset and p for patch and :Gcommit and :Gedit and :Gslipt and :Gvslipt and :Gtabedit and :Gdiff and :Gmove and :Ggrep and :Glog and :Gdelete and :Gread and :Gwrite)"
echo "vim-expand-region: (+ to expand the visual selection and _ to shrink it)"
echo "commentary-vim: Comments management (gcc for a line and gcap for a paragraph and gc in visual mode and :7,17Commentary)"
echo "pathogen: Install plugins and manage your vim runtimepath (use 'installvimplugin' or 'git clone https://github.com/yourplugin ~/.vim_runtime/sources_non_forked/nameofplugin' for example"
echo "sshrc: vim portability for ssh (use it in terminal)"
echo "nerdcommenter: Comment # (:help nerdcommenter /cc comment the current line /cn comment current line forcing nesting /c<space> and /ci [un]comment lines /cs comment with a block formatted /c$ comment from the cursor to the end of line /cu uncomment lines)"
echo "vim-sensible: a set of set:s like scrolloff -show at least on line above and below cursor- autoread file changes that can be undoned with u, incsearch that searches before pressing enter..."
echo ""
echo "### Indenters ###"
echo "vim-indent-object: Python indenter (ai and ii and al and il)"
echo ""
echo "### Syntax ###"
echo "vim-polyglot: (you can deactivate some using echo \"let g:polyglot_disabled = ['css']\"| sudo tee -a /usr/share/vim/vimrc) syntax, indent, ftplugin and other tools for ansible apiblueprint applescript arduino asciidoc blade c++11 c/c++ caddyfile cjsx clojure coffee-script cql cryptol crystal css cucumber dart dockerfile elixir elm emberscript emblem erlang fish git glsl gnuplot go graphql groovy haml handlebars haskell haxe html5 i3 jasmine javascript json  jst jsx julia kotlin  latex  less  liquid  livescript  lua  mako  markdown  mathematica nginx  nim  nix  objc ocaml octave opencl perl pgsql php plantuml powershell protobuf pug puppet purescript python-compiler python  qml  r-lang racket  ragel raml rspec ruby rust sbt scala scss slim solidity stylus swift sxhkd systemd terraform textile thrift tmux tomdoc toml twig typescript vala vbnet vcl vm vue xls yaml yard"
echo ""
echo "### Snippets ###"
echo "snipmate: Alternative to ultisnips for snippets depending the filetype (TAB for example)" 
echo "30 seconds of X: Javascript and Python3 snippets"
echo ""
echo "Syntastics and linters"
echo ":setlocal spell! (,ss)"
echo "vim-syntastic : Common interface to syntax checkers for as many languages as possible (ACPI Source Language, ActionScript, Ada, Ansible configurations, API Blueprint, AppleScript, AsciiDoc, Assembly languages, BEMHTML, Bro, Bourne shell, C, C++, C#, Cabal, Chef, CMake, CoffeeScript, Coco, Coq, CSS, Cucumber, CUDA, D, Dart, DocBook, Dockerfile, Dust, Elixir, Erlang, eRuby, Fortran, Gentoo metadata, GLSL, Go, Haml, Haskell, Haxe, Handlebars, HSS, HTML, Java, JavaScript, JSON, JSX, Julia, LESS, Lex, Limbo, LISP, LLVM intermediate language, Lua, Markdown, MATLAB, Mercury, NASM, Nix, Objective-C, Objective-C++, OCaml, Perl, Perl 6, Perl POD, PHP, gettext Portable Object, OS X and iOS property lists, Pug (formerly Jade), Puppet, Python, QML, R, Racket, RDF TriG, RDF Turtle, Relax NG, reStructuredText, RPM spec, Ruby, SASS/SCSS, Scala, Slim, SML, Solidity, Sphinx, SQL, Stylus, Tcl, TeX, Texinfo, Twig, TypeScript, Vala, Verilog, VHDL, Vim help, VimL, Vue.js, xHtml, XML, XSLT, XQuery, YACC, YAML, YANG data models, YARA rules, z80, Zope page templates, and Zsh)"
echo "merlin: Ocaml syntastic"
echo "omnisharp: C# syntastic"
#echo "vim-crystal: C but with Ruby syntax syntastic"
#echo "vim-eastwood: Clojure linter syntastic"
echo "rust: Rust syntastic (:RustFmt and :Rustplay)"
echo "vim-swift: Swift syntastic (:help ft-swift)"
echo "python-mode: Python syntastic (:help pymode)"
echo "ghcmod-vim: Haskell syntastic (:help :filetype-overview and ghc-mod type and ghc-mod check or ghc-mod lint and ghc-mod expand and ghc-mod split)"
echo ""
echo "### Hooks and Completes ###"
echo "completor: completion for python go c++ rust swift (<C-x><C-o>)"
echo "PIV: PHP completion (<C-x><C-o>)"
echo "neco-ghc: Haskell ghc-mod completion for neocomplcache/neocomplete/deoplete (:help compl-omni)"
echo "vim-hooks: (:ListVimHooks :ExecuteHookFiles :StopExecutingHooks :StartExecutingHooks)"
echo "neocomplcache: Completion from cache (:NeoComplCacheEnable :NeoComplCacheDisable)"
echo "vim-surround: Surrounding completion (:help surround cs\"\' -changes surrounding \" for \'- ds -delete surronding- cst<html> -surrounds with html tag- yss) -add parenthesis whole line-)"
}
echo vimfunctions >> $PATHOGENFOLDER/README

##Github
sudo pacman -S git --noconfirm --needed
git config --global credential.helper cache
# Set git to use the credential memory cache
git config --global credential.helper 'cache --timeout=3600'
# Set the cache to timeout after 1 hour (setting is in seconds)
read -p "Please set your git username (by default $USER): " gitusername
gitusername="${gitusername=$USER}"
git config --global user.name $gitusername
read -p "Please set your git mail  (by default $USER@localhost): " gitmail
gitmail="${gitmail=$USER@localhost}"
git config --global user.email $gitmail
read -p "Please set your core editor (by default vim): " giteditor
giteditor="${giteditor=vim}"
git config --global core.editor $giteditor
read -p "Please set your gitdiff (by default vimdiff): " gitdiff
gitdiff="${gitdiff=vimdiff}"
git config --global merge.tool $gitdiff
read -p "Do you want to create a new gpg key for git?: " creategitkey
creategitkey="${creategitkey=N}"
case "$creategitkey" in
    [yY][eE][sS]|[yY]) 
        gpg2 --full-gen-key --expert
	gpg --list-secret-keys
        ;;
    *)
        echo "So you already created a key"
	gpg --list-secret-keys
        ;;
esac
read -p "Introduce the key username (and open https://github.com/settings/keys): " keyusername
gpg --export -a $keyusername
git config --global user.signingkey $keyusername
git config --global commit.gpgsign true
git config --list
time 10
echo "Here you are an excellent Github cheatsheet https://raw.githubusercontent.com/hbons/git-cheat-sheet/master/preview.png You can also access as gitsheet"
echo "If you get stuck, run ‘git branch -a’ and it will show you exactly what’s going on with your branches. You can see which are remotes and which are local."
echo "Do not forget to add a newsshkey or clipboard your mysshkey or mylastsshkey (if you switchsshkey before) and paste it on Settings -> New SSH key and paste it there." 

### Tmux ###
sudo pacman -S tmux  --noconfirm --needed
sudo rm ~/.tmux.conf~
cp ~/.tmux.conf ~/.tmux.conf~
wget https://raw.githubusercontent.com/abueesp/Scriptnstall/master/.tmux.conf


### Tools ###
#Network tools
sudo pacman -S traceroute nmap arp-scan conntrack-tools --noconfirm --needed
yaourt -S wireshark-cli wireshark-common wireshark-qt ostinato --noconfirm --needed
yaourt -S slurm nethogs --noconfirm #tops

#Backups
sudo pacman -S duplicity deja-dup borg --noconfirm --needed 

#Disk tools
sudo pacman -S gparted hdparm -y

#Office
wget https://raw.githubusercontent.com/abueesp/Scriptnstall/master/.bc #My programmable calc
sudo pacman -S libreoffice grc unoconv detox pandoc duplicity deja-dup --noconfirm --needed #Text tools
yaourt -S apvlv --noconfirm --needed
sudo pacman -S xmlstarlet jq datamash bc gawk mawk --noconfirm --needed #XML and jquery #wc join paste cut sort uniq
sudo pacman -S blender --noconfirm --needed
sudo pacman -S krita --noconfirm --needed
yaourt -S bashblog-git --noconfirm #blog

#Other tools
sudo pacman -S brasero qemu archiso --noconfirm --needed
sudo pacman -S terminator tilix --noconfirm --needed
sudo pacman -S d-feet htop autojump iotop task atop vnstat at nemo ncdu tree recordmydesktop --noconfirm --needed
REPEATVERSION=4.0.1
REPEATVER=4_0_1
wget https://github.com/repeats/Repeat/releases/download/v$REPEATVERSION/Repeat_$REPEATVER.jar -O /usr/src/repeat.jar && pacman -S jdk8-openjdk --noconfirm --needed
#echo 'alias repeatmouse="java -jar /usr/src/repeat.jar"' | tee -a ~/.bashrc
#Blindlector: Orca
sudo pacman -S units dateutils --noconfirm --needed
sudo -H pip install when-changed #run a command (alert) when file is changed
wget https://gist.githubusercontent.com/Westacular/5996271/raw/147384089e72f4009f177cd2d5c089bb2d8e5934/birthday_second_counter.py
sudo mv birthday_second_counter.py /bin/timealive
sudo chmod +x /bin/timealive
sudo pacman -S colordiff kompare --noconfirm --needed


### Browsers ###
#Flash
sudo pacman -Rc flashplugin pepper-flash --noconfirm
yaourt -S lightspark --noconfirm --needed

#Firefox
sudo pacman -S firefox --noconfirm --needed
sudo pacman -S firefox-developer --noconfirm --needed
cd Downloads
mkdir -p extensions
cd extensions
mkdir privacy
cd privacy
wget https://addons.mozilla.org/firefox/downloads/file/839942/startpagecom_private_search_engine.xpi
wget https://www.eff.org/files/privacy-badger-latest.xpi
wget https://addons.mozilla.org/firefox/downloads/file/706680/google_redirects_fixer_tracking_remover-3.0.0-an+fx.xpi GoogleRedirectFixer.xpi
wget https://addons.mozilla.org/firefox/downloads/file/727843/skip_redirect-2.2.1-fx.xpi SkipRedirect.xpi
wget https://addons.mozilla.org/firefox/downloads/file/808841/addon-808841-latest.xpi -O AdblockPlus.xpi 
wget https://addons.mozilla.org/firefox/downloads/latest/497366/addon-497366-latest.xpi -O DisableWebRTC.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/92079/addon-92079-latest.xpi -O CookieManager.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/383235/addon-383235-latest.xpi -O FlashDisable.xpi
wget https://addons.mozilla.org/firefox/downloads/file/281702/google_privacy-0.2.4-sm+fx.xpi -O GooglePriv.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/415846/addon-415846-latest.xpi -O SelfDestructing Cookies.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/387051/addon-387051-latest.xpi -O RemoveGoogleTracking.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/722/addon-722-latest.xpi -O NoScript.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/1865/addon-1865-latest.xpi  -O AdBlock Plus.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/496120/addon-496120-latest.xpi -O LocationGuard.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/473878/addon-473878-latest.xpi -O RandomAgentSpoofer.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/229918/addon-229918-latest.xpi -O HTTPSEverywhere.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/607454/addon-607454-latest.xpi -O UBlockOrigin.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/canvasblocker/addon-534930-latest.xpi -O Avoid HTML5 Canvas.xpi
wget https://addons.mozilla.org/firefox/downloads/file/790214/umatrix-1.1.12-an+fx.xpi -O UMatrix.xpi
wget https://addons.mozilla.org/firefox/downloads/file/872067/firefox_multi_account_containers-6.0.0-an+fx-linux.xpi -O ProfileSwitcher.xpi
mkdir otherprivacy
wget https://addons.mozilla.org/firefox/downloads/latest/certificate-patrol/addon-6415-latest.xpi -O certificate patrol.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/6196/addon-6196-latest.xpi -O PassiveRecon.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/521554/addon-521554-latest.xpi -O DecentralEyes.xpi
cd ..
cd ..
wget https://addons.mozilla.org/firefox/downloads/file/910464/tab_session_manager-3.1.0-an+fx-linux.xpi -O TabSessionManager.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/355192/addon-355192-latest.xpi -O MindTheTime.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/1843/addon-1843-latest.xpi -O Firebug.xpi
wget https://addons.mozilla.org/firefox/downloads/file/387220/text_to_voice-1.15-fx.xpi -O TextToVoice.xpi
wget https://addons.mozilla.org/firefox/downloads/file/373868/soundcloud_downloader_soundgrab-0.98-fx.xpi -O Soundcloud.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/695840/addon-695840-latest.xpi -O FlashDebugger.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/3829/addon-3829-latest.xpi -O liveHTTPHeaders.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/3497/addon-3497-latest.xpi -O EnglishUSDict.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/409964/addon-409964-latest.xpi -O VideoDownloadHelper.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/export-to-csv/addon-364467-latest.xpi -O ExportTabletoCSV.xpi
wget https://addons.mozilla.org/firefox/downloads/file/769143/blockchain_dns-1.0.9-an+fx.xpi -O BlockchainDNS.xpi
#wget https://addons.mozilla.org/firefox/downloads/latest/perspectives/addon-7974-latest.xpi -O perspectivenetworknotaries.xpi
wget https://www.roboform.com/dist/roboform-firefox.xpi
mkdir extratools
wget https://addons.mozilla.org/firefox/downloads/latest/5791/addon-5791-latest.xpi -O FlagFox.xpi
wget https://addons.mozilla.org/en-US/firefox/downloads/latest/2109/addon-2109-latest.xpi -O FEBEBackups.xpi
#wget https://addons.mozilla.org/firefox/downloads/latest/363974/addon-363974-latest.xpi -O Lightbeam.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/tabletools2/addon-296783-latest.xpi -O TableTools2.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/748/addon-748-latest.xpi -O Greasemonkey.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/7447/addon-7447-latest.xpi -O NetVideoHunter.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/1237/addon-1237-latest.xpi -O QuickJava.xpi
wget https://addons.mozilla.org/firefox/downloads/file/502726/colorfultabs-31.0.8-fx+sm.xpi -O ColorfulTabs.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/193270/addon-193270-latest.xpi -O PrintEdit.xpi
wget https://addons.mozilla.org/firefox/downloads/file/342774/tineye_reverse_image_search-1.2.1-fx.xpi -O TinyEyeReverseImageSearch.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/161670/addon-161670-latest.xpi -O FlashFirebug.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/tab-groups-panorama/addon-671381-latest.xpi -O Tabgroups.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/532/addon-532-latest.xpi -O LinkChecker.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/5523/addon-5523-latest.xpi -O guiconfigextraoptions.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/10586/addon-10586-latest.xpi -O URLShortener.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/8661/addon-8661-latest.xpi -O WorldIP.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/390151/addon-390151-latest.xpi -O TOS.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/3456/addon-3456-latest.xpi -O WOT.xpi
wget https://addons.mozilla.org/firefox/downloads/file/140447/cryptofox-2.2-fx.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/copy-as-plain-text/addon-344925-latest.xpi -O CopyasPlainText.xpi
wget https://addons.mozilla.org/firefox/downloads/file/229626/sql_inject_me-0.4.7-fx.xpi 
wget https://addons.mozilla.org/firefox/downloads/file/215802/rightclickxss-0.2.1-fx.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/3899/addon-3899-latest.xpi -O HackBar.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/wappalyzer/addon-10229-latest.xpi -O Wappanalyzer.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/344927/addon-344927-latest.xpi -O CookieExportImport.xpi
wet https://addons.mozilla.org/firefox/downloads/file/204186/fireforce-2.2-fx.xpi 
wget https://addons.mozilla.org/firefox/downloads/file/224182/csrf_finder-1.2-fx.xpi 
wget https://addons.mozilla.org/firefox/downloads/file/345004/live_http_headers_fixed_by_danyialshahid-0.17.1-signed-sm+fx.xpi
wget https://addons.mozilla.org/firefox/downloads/file/782839/recap-1.1.8-an+fx.xpi -O RECAPforsearchingUSLawDB.xpi
cd ..
cd ..
cd ..
cd ~/.mozilla/firefox/*.default
#vim -c ':%s/user_pref("browser.safebrowsing.*//g' -c ":wq" prefs.js
vim -c ':%s/user_pref("browser.newtabpage.activity-stream.impressionId".*//g' -c ":wq" prefs.js
vim -c ':%s/user_pref("toolkit.telemetry.cachedClientID".*//g' -c ":wq" prefs.js
vim -c ':%s|user_pref("privacy.trackingprotection.pbmode.enabled", false);|user_pref("privacy.trackingprotection.pbmode.enabled", true);|g' -c ":wq" prefs.js
cd

#Opera
sudo pacman -S opera opera-developer --noconfirm --needed

#Vivaldi
sudo pacman -S vivaldi --noconfirm --needed

#Chromium
sudo pacman -S chromium --noconfirm --needed
#vim -c ":%s|google.com|ixquick.com|g" -c ":wq" ~/.config/chromium/Default/Preferences
#vim -c ":%s|Google|Ixquick|g" -c ":wq" ~/.config/chromium/Default/Preferences
#vim -c ":%s|yahoo.com|google.jp/search?q=%s&pws=0&ei=#cns=0&gws_rd=ssl|g" -c ":wq" ~/.config/chromium/Default/Preferences
#vim -c ":%s|Yahoo|Google|g" -c ":wq" ~/.config/chromium/Default/Preferences
#CREATEHASH=$(sha256sum ~/.config/chromium/Default/Preferences)
#HASH=$(echo $CREATEHASH | head -n1 | sed -e 's/\s.*$//')
#HASHPREF=$(echo $HASH | awk '{print toupper($0)}')
#vim -c ":%s/"super_mac":".*"}}/"super_mac":"$HASHPREF"}}/g' -c ":wq" ~/.config/chromium/Default/'Secure Preferences'
chromium https://chrome.google.com/webstore/detail/url-tracking-stripper-red/flnagcobkfofedknnnmofijmmkbgfamf
chromium https://chrome.google.com/webstore/detail/dont-track-me-google/gdbofhhdmcladcmmfjolgndfkpobecpg
chromium https://chrome.google.com/webstore/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm
chromium https://chrome.google.com/webstore/detail/adblock/gighmmpiobklfepjocnamgkkbiglidom
chromium https://chrome.google.com/webstore/detail/session-buddy/edacconmaakjimmfgnblocblbcdcpbko
chromium https://chrome.google.com/webstore/detail/project-naptha/molncoemjfmpgdkbdlbjmhlcgniigdnf
chromium https://chrome.google.com/webstore/detail/auto-form-filler/cfghpjmgdnienmgcajbmjjemfnnmldlh 
chromium https://chrome.google.com/webstore/detail/autoform/fdedjnkmcijdhgbcmmjdogphnmfdjjik
chromium https://chrome.google.com/webstore/detail/m-i-m/jlppachnphenhdidmmpnbdjaipfigoic
chromium https://chrome.google.com/webstore/detail/librarian-for-arxiv-ferma/ddoflfjcbemgfgpgbnlmaedfkpkfffbm
chromium https://chrome.google.com/webstore/detail/noiszy/immakaidhkcddagdjmedphlnamlcdcbg
chromium https://chrome.google.com/webstore/detail/ciiva-search/fkmanbkfjcpkhonmmdopjmjopbclegel
chromium https://blockchain-dns.info/files/BDNS-1.0.8.crx
chromium https://chrome.google.com/webstore/detail/video-downloadhelper/lmjnegcaeklhafolokijcfjliaokphfk 

#Icecat
sudo pacman -S icecat --noconfirm --needed

#Terminal explorers: Elinks


### Calc Tools ###
cd Documents
mkdir bctools
cd bctools
wget http://phodd.net/gnu-bc/code/array.bc
wget http://phodd.net/gnu-bc/code/collatz.bc    
wget http://phodd.net/gnu-bc/code/digits.bc    
wget http://phodd.net/gnu-bc/code/funcs.bc   
wget http://phodd.net/gnu-bc/code/interest.bc      
wget http://phodd.net/gnu-bc/code/melancholy.bc      
wget http://phodd.net/gnu-bc/code/primes.bc      
wget http://phodd.net/gnu-bc/code/thermometer.bc      
wget http://phodd.net/gnu-bc/code/cf.bc       
wget http://phodd.net/gnu-bc/code/complex.bc     
wget http://phodd.net/gnu-bc/code/factorial.bc      
wget http://phodd.net/gnu-bc/code/intdiff.bc      
wget http://phodd.net/gnu-bc/code/logic.bc      
wget http://phodd.net/gnu-bc/code/output_formatting.bc      
wget https://raw.githubusercontent.com/sevo/Calc/master/bc/rand.bc
cd ..
cd ..


### Python ###
sudo pacman -S python python3 --noconfirm --needed
sudo pacman -S python-pip --nonconfirm --needed

#Some Python tools
sudo -H pip install percol #Indexer
sudo -H pip install shyaml csvkit #yaml csv

#youtube-dl and soundcloud
sudo wget https://yt-dl.org/downloads/latest/youtube-dl -O /usr/bin/youtube-dl
sudo chmod a+rx /usr/bin/youtube-dl
sudo -H pip install scdl

#Saltpack
sudo -H pip install setuptools
sudo -H pip install saltpack

### Communications ###
#IRC
sudo pacman -S weechat hexchat --noconfirm --needed

#Intranet
yaourt -S beebeep --noconfirm --needed

#P2P Videocalls and messaging
sudo pacman -S libringclient ring-daemon ring-gnome --noconfirm --needed
#yaourt -S jitsi --noconfirm --needed
#yaourt -S qtox --noconfirm --needed

#All-in-a-box
yaourt -S rambox-bin --noconfirm --needed


### Rootkit checking and Audits ###
#Unhide
echo "Unhide — A forensic tool to find processes hidden by rootkits, LKMs or by other techniques. "
sudo pacman unhide -S --noconfirm --needed
sudo unhide -m -d sys procall brute reverse
printf '[Unit]
Unit sudo unhide -m -d sys procall brute reverse
Description=Run unhide weekly and on boot

[Timer]
#OnBootSec=15min
#OnUnitActiveSec=1w
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
#for mail check https://wiki.archlinux.org/index.php/Systemd/Timers#MAILTO' | sudo tee /etc/systemd/system/unhide.timer
printf'[Unit]
Unit=sudo rkhunter --skip-keypress --summary --check --hash sha256 -x
Description=Run unhide weekly and on boot

[Timer]
#OnBootSec=15min
#OnUnitActiveSec=1w
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
#for mail check https://wiki.archlinux.org/index.php/Systemd/Timers#MAILTO' |  sudo tee /etc/systemd/system/unhide.timer
sudo chmod u+rwx /etc/systemd/system/unhide.timer 
sudo chmod go-rwx /etc/systemd/system/unhide.timer 

#Rkhunter
echo "Rkhunter — Checks machines for the presence of rootkits and other unwanted tools."
sudo pacman rkhunter -S --noconfirm --needed #Rkhunter instead of chkrootkit
sudo touch /etc/rkhunter.conf
echo 'SCRIPTWHITELIST="/usr/bin/egrep"' | sudo tee -a /etc/rkhunter.conf #false positive In Arch it is a bash script not a binary
echo 'SCRIPTWHITELIST="/usr/bin/fgrep"' | sudo tee -a /etc/rkhunter.conf #false positive In Arch it is a bash script not a binary
echo 'SCRIPTWHITELIST="/usr/bin/ldd"' | sudo tee -a /etc/rkhunter.conf #false positive In Arch it is a bash script not a binary
echo 'EXISTWHITELIST="/usr/bin/vendor_perl/GET"' | sudo tee -a /etc/rkhunter.conf #false positive Not in Arch installations
echo 'ALLOWHIDDENFILE="/etc/.updated"' | sudo tee -a /etc/rkhunter.conf #false positive This file was created by systemd-update-done. Its only purpose is to hold a timestamp of the time this directory was updated. See man:systemd-update-done.service(8).
echo 'ALLOWHIDDENFILE="/usr/share/man/man5/.k5login.5.gz"' | sudo tee -a /etc/rkhunter.conf #false positive duplicated for krb5 package
echo 'ALLOWHIDDENFILE="/usr/share/man/man5/.k5login.5.gz"' | sudo tee -a  /etc/rkhunter.conf #false positive duplicated for krb5 package
echo 'ALLOWDEVFILE="/dev/dsp"' | sudo tee -a  /etc/rkhunter.conf #false positive https://wiki.archlinux.org/index.php/Open_Sound_System
sudo chmod go-rwx /etc/rkhunter.conf
sudo rkhunter --propupd #Avoid warning abuot rkhunter.dat
sudo rkhunter --update
sudo rkhunter --skip-keypress --summary --check --hash sha256 -x --configfile /etc/rkhunter.conf
sudo cat /var/log/rkhunter.log | grep -A 6 Warning
sudo cat /var/log/rkhunter.log | grep -A 6 Hidden

#Lynis
echo "Lynis — Security and system auditing tool to harden Unix/Linux systems. https://cisofy.com/lynis/"
sudo pacman -S lynis --noconfirm --needed
sudo lynis audit system

#Tiger
echo "Tiger — Security tool that can be use both as a security audit and intrusion detection system. http://www.nongnu.org/tiger/" 
aurman -S tiger --needed --noconfirm --noedit
sudo vim -c ":%s|which ypcat|which ypcat 2>/dev/null|g" -c ":wq" /usr/share/tiger/systems/default/gen_passwd_sets #only for dns/ldap servers
sudo vim -c ":%s|which niscat|which niscat 2>/dev/null|g" -c ":wq" /usr/share/tiger/systems/default/gen_passwd_sets #only for dns/ldap servers
sudo tiger

#Tor-browser
LANGUAGE=$(locale | grep LANG | cut -d'=' -f 2 | cut -d'_' -f 1)
aurman -S tor-browser-$LANGUAGE --needed --noconfirm --noedit

### Autoremove and Snapshot ###
sudo pacman -Rns $(pacman -Qtdq) --noconfirm
sudo pacman -Qq | sudo paccheck --sha256sum --quiet
#snapper -c initial create --description initial #Make snapshot initial (no chsnap for ext4)


### Frugalware Stable ISO
#wget http://www13.frugalware.org/pub/frugalware/frugalware-stable-iso/fvbe-2.1-gnome-x86_64.iso

### Security Onion
#wget https://github.com/Security-Onion-Solutions/security-onion/raw/master/sigs/securityonion-14.04.5.11.iso.sig
#wget https://github.com/Security-Onion-Solutions/security-onion/releases/download/v14.04.5.11_20180328/securityonion-14.04.5.11.iso

### Tails
#wget https://tails.braingap.uk/tails/stable/tails-amd64-3.6.2/tails-amd64-3.6.2.iso
#wget https://tails.boum.org/torrents/files/tails-amd64-3.6.2.iso.sig

echo "EOF"
