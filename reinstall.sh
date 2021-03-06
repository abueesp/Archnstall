sudo pacman -S slim --noconfirm --needed
sudo mv /etc/systemd/system/display-manager.service /etc/systemd/system/display-manager.service.bak
sudo systemctl enable slim.service

### On development: ### GUIDES:: https://www.archlinux.org/feeds/news/ https://wiki.archlinux.org/index.php/IRC_channel (add to weechat) https://www.archlinux.org/feeds/  https://security.archlinux.org/
#DNS (unbound resolv.conf dnssec dyndns) and Firewall
#emacs https://melpa.org/
#create encfs alias and add gui
#gdb vs strace vs perf trace vs reptyr vs sysdig vs dtrace
# http://www.brendangregg.com/overview.html
# http://www.brendangregg.com/perf.html
# http://www.brendangregg.com/blog/2015-07-08/choosing-a-linux-tracer.html
# https://www.slideshare.net/brendangregg/velocity-2015-linux-perf-tools/105
# https://kernelnewbies.org/KernelGlossary https://0xax.gitbooks.io/linux-insides/content/Booting/
# PEDA vs Radare2 https://github.com/longld/peda
# http://160592857366.free.fr/joe/ebooks/ShareData/Design%20of%20the%20Unix%20Operating%20System%20By%20Maurice%20Bach.pdf
#next4 snapper?
#https://wiki.archlinux.org/index.php/Trusted_Users#How_do_I_become_a_TU.3F
#customizerom

### Restoring Windows on Grub2 ###
sudo os-prober
GRUBPROBER=$(sudo os-prober)
if [ -n "$GRUBPROBER" ]
            then
                        sudo grub-mkconfig -o /boot/grub/grub.cfg
            else
                        echo "No Windows installed"
fi

### MAC ###
echo "Randomize MAC"
echo ''
echo '[connection-mac-randomization]' | sudo tee -a /etc/NetworkManager/NetworkManager.conf
echo '# Randomize MAC for every ethernet connection' | sudo tee -a /etc/NetworkManager/NetworkManager.conf
echo 'ethernet.cloned-mac-address=random' | sudo tee -a /etc/NetworkManager/NetworkManager.conf
echo '# Generate a random MAC for each WiFi and associate the two permanently.' | sudo tee -a /etc/NetworkManager/NetworkManager.conf
echo 'wifi.cloned-mac-address=stable' | sudo tee -a /etc/NetworkManager/NetworkManager.conf

### Optimize Pacman, Update, Upgrade, Snapshot ###
sudo pacman -Sc --noconfirm #Improving pacman database access speeds reduces the time taken in database-related tasks
sudo pacman-key --refresh-keys #keyring update
sudo pacman -Syu --noconfirm #update & upgrade
#sudo pacman -S snap-pac --noconfirm --needed #Installing snapper
#sudo snapper -c root create-config / #Create snapshot folder (no chsnap for ext4)
#snapper -c preupgrade create --description preupgrade -c number 1 #Make snapshot preupgrade  (no chsnap for ext4)

### Tor ###
sudo pacman -S arch-install-scripts base arm --noconfirm --needed
sudo pacman -S tor torsocks --noconfirm --needed

# Configuration
# Being able to run tor as a non-root user, and use a port lower than 1024 you can use kernel capabilities. As any upgrade to the tor package will reset the permissions, consider using pacman#Hooks, to automatically set the permissions after upgrades.
sudo setcap CAP_NET_BIND_SERVICE=+eip /usr/bin/tor
echo "[Action]
Description = Ports lower than 1024 available for Tor
Exec = sudo setcap CAP_NET_BIND_SERVICE=+eip /usr/bin/tor" | sudo tee -a /usr/share/libalpm/hooks/tor.hook
export TORPORT=$(shuf -i 2000-65000 -n 1)
echo "TORPORT $TORPORT"
export TORCONTROLPORT=$(shuf -i 2000-65000 -n 1)
echo "TORCONTROLPORT $TORCONTROLPORT"
export TORHASH=$(echo -n $RANDOM | sha256sum)
sudo vim -c ":%s/#SocksPort 9050/SocksPort $TORPORT/g" -c ":wq" /etc/tor/torrc
sudo vim -c ":%s/#ControlPort 9051/#ControlPort $TORCONTROLPORT/g" -c ":wq" /etc/tor/torrc
sudo vim -c ":%s/#HashedControlPassword*$/#HashedControlPassword 16:${TORHASH:-2}/g" -c ":wq" /etc/tor/torrc
echo "StrictNodes 1" | sudo tee -a /etc/tor/torrc
echo "ExitNodes " | sudo tee -a /etc/tor/torrc
echo "ExcludeNodes {us},{uk},{ca},{se},{fr},{pt},{de},{dk},{es},{nl},{kr},{ee}" | sudo tee -a /etc/tor/torrc
if [ ! -f /etc/tor/torsocks.conf ];
then
    sudo touch /etc/tor/torsocks.conf
    echo "TorPort $TORPORT" | sudo tee -a /etc/tor/torsocks.conf
else
    sudo vim /etc/tor/torsocks.conf -c ":%s/#TorPort 9050/TorPort $TORPORT/g" -c ":wq"

fi

# All DNS queries to Tor
export TORDNSPORT=$(shuf -i 2000-65000 -n 1)
echo "DNSPort $TORDNSPORT"  | sudo tee -a /etc/tor/torrc
echo "AutomapHostsOnResolve 1" | sudo tee -a /etc/tor/torrc
echo "AutomapHostsSuffixes .exit,.onion" | sudo tee -a /etc/tor/torrc
sudo pacman -S dnsmasq --noconfirm --needed
sudo vim -c ":%s,#port=,port=$TORDNSPORT ,g" -c ":wq" /etc/dnsmasq.conf
sudo vim -c ":%s,#conf-file=/usr/share/dnsmasq/trust-anchors.conf,conf-file=/usr/share/dnsmasq/trust-anchors.conf,g" -c ":wq" /etc/dnsmasq.conf
sudo vim -c ":%s,#dnssec,dnssec,g" -c ":wq" /etc/dnsmasq.conf
sudo vim -c ":%s,#no-resolv,no-resolv,g" -c ":wq" /etc/dnsmasq.conf
sudo vim -c ":%s,#server=/localnet/192.168.0.1,server=127.0.0.1,g" -c ":wq" /etc/dnsmasq.conf
sudo vim -c ":%s,#listen-address=,listen-address=127.0.0.1,g" -c ":wq" /etc/dnsmasq.conf
sudo vim -c ":%s,#nohook resolv.conf,nohook resolv.conf,g" -c ":wq" /etc/dhcpcd.conf

# Pacman over Tor/
sudo cp /etc/pacman.conf /etc/pacmantor.conf
sudo vim -c ':%s.#XferCommand = /usr/bin/curl.#XferCommand = /usr/bin/curl --socks5-hostname localhost:$TORPORT -C - -f %u > %o" \n#XferCommand = /usr/bin/curl.g' -c ':wq' /etc/pacmantor.conf

#Create user
export TORUSER="tor"
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
sudo cp -r /etc/hosts           $TORCHROOT/etc/hosts
sudo cp /etc/host.conf       $TORCHROOT/etc/host.conf
sudo cp -r /etc/localtime       $TORCHROOT/etc/localtime
sudo cp /etc/nsswitch.conf   $TORCHROOT/etc/nsswitch.conf
sudo cp /etc/resolv.conf     $TORCHROOT/etc/resolv.conf
sudo cp -r /etc/tor            $TORCHROOT/etc/tor #which contains torrc (and torsocks.conf despite not needed)
sudo mkdir $TORCHROOT/root
sudo mkdir $TORCHROOT/root/tor
sudo chown -R tor:tor $TORCHROOT/root/tor
sudo cp -r /usr/bin/tor         $TORCHROOT/usr/bin/tor
sudo cp -r /lib/libnss* /lib/libnsl* /lib/ld-linux-*.so* /lib/libresolv* /lib/libgcc_s.so* $TORCHROOT/usr/lib/
for F in $(ldd  -r /usr/bin/tor | awk '{print $3}'|grep --color=never "^/" | sed 's/^.*\(\/lib[0-9]*\/[a-z]*\).*/\/usr\1*/g'); do   sudo cp -R -f ${F}  $TORCHROOT/${F%/*}/.  ;  done
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
# Checking conf
sudo cp -r $TORCHROOT/var/lib/tor /var/lib/tor
sudo chown -R tor:tor $TORCHROOT/var/lib/tor
sudo cp /etc/tor/ $TORCHROOT/etc/tor/
sudo cp /etc/dnsmasq.conf $TORCHROOT/etc/dnsmasq
sudo cp /etc/dhcpcd.conf $TORCHROOT/etc/dhcpcd.conf
sudo cp /etc/pacmantor.conf $TORCHROOT/etc/pacman.conf

# Running Tor in a systemd-nspawn container with a virtual network interface [which is more secure than chroot]
TORCONTAINER=tor-exit #creating container and systemd service
SRVCONTAINERS=/srv/container
VARCONTAINERS=/var/lib/container/
sudo mkdir $SRVCONTAINERS/$TORCONTAINER
sudo pacstrap -i -c -d $SRVCONTAINERS/$TORCONTAINER base tor arm --noconfirm --needed
sudo mkdir $VARCONTAINERS
sudo ln -s $SRVCONTAINERS/$TORCONTAINER $VARCONTAINERS/$TORCONTAINER
sudo mkdir /etc/systemd/system/systemd-nspawn@$TORCONTAINER.service.d
sudo ifconfig #adding container ad-hoc vlan
read -p "Choose your host network interface for creating a new VLAN (wlp1s0 by default): " INTERFACE
INTERFACE="${INTERFACE:=wlp1s0}"
VLANINTERFACE="${INTERFACE:0:2}.tor"
sudo ip link add link $INTERFACE name $VLANINTERFACE type vlan id $(((RANDOM%4094)+1))
sudo ip addr add 10.0.0.1/24 brd 10.0.0.255 dev $VLANINTERFACE
sudo sudo ip link set $VLANINTERFACE up
networkctl
printf "[Service]
ExecStart=
ExecStart=/usr/bin/systemd-nspawn --quiet --boot --keep-unit --link-journal=guest --network-macvlan=$VLANINTERFACE --private-network --directory=$VARCONTAINERS/$TORCONTAINER LimitNOFILE=32768" | sudo tee -a /etc/systemd/system/systemd-nspawn@$TORCONTAINER.service.d/$TORCONTAINER.conf #config file [yes, first empty ExecStart is required]. You can use --ephemeral instead of --keep-unit --link-journal=guest and then you can delete the machine
sudo systemctl daemon-reload
TERMINAL=$(tty)
TERM="${TERMINAL:5:4}0"
echo "$TERM" | sudo tee -a $SRVCONTAINERS/$TORCONTAINER/etc/securetty
TERM="${TERMINAL:5:4}1"
echo "$TERM" | sudo tee -a $SRVCONTAINERS/$TORCONTAINER/etc/securetty
TERM="${TERMINAL:5:4}2"
echo "$TERM" | sudo tee -a $SRVCONTAINERS/$TORCONTAINER/etc/securetty
TERM="${TERMINAL:5:4}3"
echo "$TERM" | sudo tee -a $SRVCONTAINERS/$TORCONTAINER/etc/securetty
TERM="${TERMINAL:5:4}4"
echo "$TERM" | sudo tee -a $SRVCONTAINERS/$TORCONTAINER/etc/securetty
TERM="${TERMINAL:5:4}5"
echo "$TERM" | sudo tee -a $SRVCONTAINERS/$TORCONTAINER/etc/securetty
# Checking conf
sudo cp -R $SRVCONTAINERS/$TORCONTAINER/var/lib/tor /var/lib/tor
sudo chown -R root:root $SRVCONTAINERS/$TORCONTAINER/var/lib/tor
sudo cp -R /etc/tor/ $SRVCONTAINERS/$TORCONTAINER/etc/tor/
sudo cp /etc/dnsmasq.conf $SRVCONTAINERS/$TORCONTAINER/etc/dnsmasq.conf
sudo cp /etc/dhcpcd.conf $SRVCONTAINERS/$TORCONTAINER/etc/dhcpcd.conf
sudo cp /etc/pacmantor.conf $SRVCONTAINERS/$TORCONTAINER/etc/pacman.conf
sudo systemctl daemon-reload
sudo systemd-nspawn --boot --directory=$SRVCONTAINERS/$TORCONTAINER
sudo systemctl list-machines
systemctl start systemd-nspawn@$TORCONTAINER.service
machinectl -a
echo "Login root without password. Set passwd. Bring VLAN up with ip link set mv-$VLANINTERFACE up. Add a user with useradd. Login user and set passwd. Use ctrl+shift+] to exit"
machinectl login $TORCONTAINER
networkctl
#machine enable $TORCONTAINER #enable at boot otherwise you need to start it every time

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
sudo chage -M -1 365 "$USER" #force to change password every 90 days (-M, -W only for warning) but without password expiration (-1, -I will set a different days for password expiration, and -E a data where account will be locked)
sudo chage -W 90 "$USER" #Warning days for password changing
pwmake 512 #Create a secure 512 bits password
chage -l "$USER" #Change password
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
sudo mkdir -p /etc/banners
echo "Hello. All activity on this server is logged. Inappropriate uses and access will result in defensive counter-actions." | sudo tee -a /etc/banners/sshd
echo "ALL : ALL : spawn /bin/echo $date %c %d >> /var/log/intruder_alert" | sudo tee -a /etc/hosts.deny ##log any connection attempt from any IP and send the date to intruder_alert logfile
echo "in.telnetd : ALL : severity emerg" | sudo tee -a /etc/hosts.deny ##log any attempt to connect to in.telnetd posting emergency log messages directly to the console

# Encryption of filesystems (Encrypt disk to avoid init=/bin/sh)
sudo pacman -S encfs pam_encfs --noconfirm --needed #Check https://wiki.archlinux.org/index.php/Disk_encryption#Comparison_table

# Kernel hardening
sudo pacman -S linux-hardened --needed --noconfirm
echo "kernel.dmesg_restrict = 1" | sudo tee -a /etc/sysctl.d/50-dmesg-restrict.conf #Restricting access to kernel logs
echo "kernel.kptr_restrict = 1" | sudo tee -a /etc/sysctl.d/50-kptr-restrict.conf #Restricting access to kernel pointers in the proc filesystem

# Bluetooth
sudo vim -c ':%s,\#Autoenable=False,Autoenable=False,g' -c ':wq' /etc/bluetooth/main.conf
sudo rfkill block bluetooth
printf "[General]
Enable=Socket" | sudo tee -a /etc/bluetooth/audio.conf #A2DP
sudo vim -c ':%s.; enable-lfe-remixing = no.enable-lfe-remixing = yes.g' -c ':wq' /etc/pulse/daemon.conf
sudo vim -c "%s,\#load-module module-switch-on-connect,load-module module-switch-on-connect,g" -c ":wq" /etc/pulse/default.pa
sudo vim -c "%s,\#load-module module-suspend-on-idle,load-module module-suspend-on-idle,g" -c ":wq" /etc/pulse/default.pa
sudo vim -c 's,    /usr/bin/pactl load-module module-x11-xsmp “display=$DISPLAY session_manager=$SESSION_MANAGER” > /dev/null,
\n    /usr/bin/pactl load-module module-x11-xsmp "display=$DISPLAY session_manager=$SESSION_MANAGER" > /dev/null
\n    /usr/bin/pactl load-module module-bluetooth-policy
\n    /usr/bin/pactl load-module module-bluetooth-discover,g' -c "wq" /usr/bin/start-pulseaudio-x11 #automatic pavucontrol recognition
echo "load-module module-bluetooth-discover" | sudo tee -a "/etc/pulse/system.pa"
echo "load-module module-bluetooth-policy" | sudo tee -a "/etc/pulse/system.pa"
printf "[phonesim]
Driver=phonesim
Address=1.1.1.1
Port=12345" | sudo tee -a /etc/ofono
sudo useradd -g bluetooth pulse
pulseaudio -k
pulseaudio --start --daemon
sudo systemctl stop bluetooth.service
sudo pkill -9 /usr/lib/bluetooth/obexd
sudo pkill -9 /usr/lib/bluetooth/bluetoothd
sudo systemctl start bluetooth.service

#UDF DVDs
echo "/dev/sr0 /media/cdrom0 udf,iso9660 user,noauto,exec,utf8 0 0" | sudo tee -a /etc/fstab

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
#echo "export TMOUT=\"\$(( 60*10 ))\"; #to exclude X11 from this rule, delete export word
#[ -z \"\$DISPLAY\" ] && export TMOUT;
#case \$( /usr/bin/tty ) in
#	/dev/tty[0-9]*) export TMOUT;;
#esac" | sudo tee -a /etc/profile.d/shell-timeout.sh
#echo 'Section "ServerFlags"
#    Option "DontVTSwitch" "True"
#EndSection' | sudo tee -a /usr/share/X11/xorg.conf.d/50-notsudo.conf

# Extra recommendations
echo ">>> Do not use rlogin, rsh, and telnet <<<"
echo ">>> Take care of securing sftp, auth, nfs, rpc, postfix, samba and sql https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Security_Guide/sec-Securing_Services.html <<<"
echo ">>> Take care of securing Docker https://wiki.archlinux.org/index.php/Docker#Insecure_registries https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_atomic_host/7/html-single/getting_started_with_containers/ <<<"


### Network ###
# SSH
if [ ! -f /etc/ssh/sshd_config ];
then
    echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config
    echo "Protocol 2" | sudo tee -a /etc/ssh/sshd_config
    echo "MaxAuthTries 3" | sudo tee -a etc/ssh/sshd_config
else
    sudo vim /etc/ssh/sshd_config -c ':%s/PermitRootLogin without password/PermitRootLogin no/g' -c ':wq'
    sudo vim /etc/ssh/sshd_config -c ':%s/Protocol 2,1/Protocol 2/g' -c ':wq'
    sudo vim /etc/ssh/sshd_config -c ":%s/MaxAuthTries 6/MaxAuthTries 3/g" -c ":wq"

fi

# SSHguard (prefered over Fail2ban)
sudo pacman -S sshguard --noconfirm --needed
sudo vim -c ":%s,BLACKLIST_FILE=120:/var/db/sshguard/blacklist.db,BLACKLIST_FILE=50:/var/db/sshguard/blacklist.db,g" -c ":wq" /etc/sshguard.conf #Danger level: 5 failed logins -> banned
sudo vim -c ":%s,THRESHOLD=30,THRESHOLD=10,g" -c ":wq"  /etc/sshguard.conf
sudo systemctl enable --now sshguard.service

# OpenSSL and NSS
sudo pacman -S openssl nss --noconfirm --needed
cat "$(locate ca-certificates)" #check all certificates
#blacklist ssl symanteccertificate
wget https://crt.sh/?d=19538258
sudo mv index.html?d=19538258 /etc/ca-certificates/trust-source/blacklist/19538258-Symantec.crt  #Blacklist Symantec SSL Cert
sudo update-ca-trust

# Suricata IDS/IPS (prefered over Snort https://www.aldeid.com/wiki/Suricata-vs-snort)
gpg2 --keyserver ha.pool.sks-keyservers.net --recv-keys 801C7171DAC74A6D3A61ED81F7F9B0A300C1B70D
git clone https://aur.archlinux.org/suricata.git
cd suricata
makepkg -si --noconfirm # --enable-profiling-locks
cd ..
sudo rm -r suricata
gpg2 --delete-secret-and-public-keys --batch --yes 801C7171DAC74A6D3A61ED81F7F9B0A300C1B70D
#basic conf
sudo rm /etc/suricata/suricata.yaml #delete conf file by default to create a new one
if [ ! -f /etc/suricata/suricata.yaml ]; then
	sudo touch /etc/suricata/suricata.yaml #using echo instead of printf by reason of %
	echo '%YAML 1.1
---
# - dyre_sslipblacklist_aggressive.rules    # available in suricata sources under rules dir
default-log-dir: /var/log/suricata/     # where you want to store log files
classification-file: /etc/suricata/classification.config
reference-config-file: /etc/suricata/reference.config
HOME-NET: "[192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,127.0.0.1/8]"                # HOME_NET is deprecated
magic-file: /usr/share/file/misc/magic.mgc
stats:
  enabled: yes
  interval: 10
  filename: stats.log
  totals: yes       # stats for all threads merged together
  threads: yes       # per thread stats
  null-values: yes  # print counters that have value 0
host-mode: auto #If set to auto, the variable is internally switch to router in IPS mode and sniffer-only in IDS mode.
outputs:
fast:
  enabled: yes
  filename: fast.log
  append: yes
  filetype: regular   #regular, unix_stream or unix_dgram
eve-log:
  enabled: no
alert-debug:
  enabled: yes
  filename: alert-debug.log
  append: yes
  filetype: regular   #regular, unix_stream or unix_dgram
drop:
  enabled: yes
  filename: drop.log
  append: yes
  filetype: regular   #regular, unix_stream or unix_dgram
  alerts: yes      # log alerts that caused drops
  flows: all       # start or all: 'start' logs only a single drop
logging:
  default-log-level: debug
coredump:
  max-dump: unlimited
  host-mode: auto
  runmode: workers
  default-packet-size: 9014
legacy:
  uricontent: enabled
engine-analysis:  # enables printing reports for fast-pattern for every rule.
  rules-fast-pattern: yes # enables printing reports for each rule
  rules: yes #recursion and match limits for PCRE where supported
pcre:
  match-limit: 3500
  match-limit-recursion: 1500
vlan:
  use-for-tracking: true
#reputation-categories-file: /usr/local/etc/suricata/iprep/categories.txt
  #default-reputation-path: /usr/local/etc/suricata/iprep
default-rule-path: /etc/suricata/rules/' | sudo tee -a /etc/suricata/suricata.yaml #continue below activating rules
else
	sudo vim -c ":%s,# -,-,g" -c ":wq" /etc/suricata/suricata.yaml #when file exists
fi
#Activating rules
suricatasslrule(){
url=$SSLRULES".rules"
agurl=$SSLRULES"_aggressive.rules"
wget "https://sslbl.abuse.ch/blacklist/$url"
sudo mv "$url" "/etc/suricata/rules/$url"
wget "https://sslbl.abuse.ch/blacklist/$agurl"
sudo mv "$agurl" "/etc/suricata/rules/$agurl"
echo "		- $url   # available in suricata sources under rules dir" | sudo tee /etc/suricata/suricata.yaml #activate ssl blacklist rules
echo "#		- $agurl    # available in suricata sources under rules dir" | sudo tee /etc/suricata/suricata.yaml #activate ssl aggressive blacklist
}
SSLRULES=sslblacklist
suricatasslrule
SSLRULES=dyre_sslipblacklist
suricatasslrule
#other confs
wget https://raw.githubusercontent.com/OISF/suricata/master/suricata.yaml.in
echo "## FULL EXPLANATION https://redmine.openinfosecfoundation.org/projects/suricata/wiki/Suricatayaml ##" | tee -a suricata.yaml.in
sudo mv suricata.yaml.in /etc/suricata/suricata-defaultOISFexample.yaml
wget https://redmine.openinfosecfoundation.org/attachments/download/1340/suricata.yaml
vim -c "%s/  - drop:/  - drop:\r      alerts: yes      # log alerts that caused drops\r      flows: all       # start or all: 'start' logs only a single drop\n/g" -c ":wq" suricata.yaml #using /r instead of /n in vim because /n is null
sudo mv suricata.yaml /etc/suricata/suricata-specificNOSERVexample.yaml
#restarting suricata
if [ ! -f /var/run/suricata.pid ];
then
	sudo pkill -9 suricata
	sudo killall suricata
	sudo rm /var/run/suricata.pid
fi
sudo suricata -c /etc/suricata/suricata.yaml -i $INTERFACE -D #start suricata and enable interfaces, the -s allows specific rules
#enable at boot
echo "[Unit]
Description=Suricata Intrusion Detection Service listening on '%I'
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/suricata -c /etc/suricata/suricata.yaml -i %i -D
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target" | sudo tee -a /usr/lib/systemd/system/suricata@$INTERFACE.service
sudo systemctl enable --now suricata@$INTERFACE.service
echo "[Unit]
Description=Suricata Intrusion Detection Service listening on '%I'
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/suricata -c /etc/suricata/suricata.yaml -i %i -D
ExecReload=/bin/kill -HUP \$MAINPID

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
#iptables -t filter -I OUTPUT 1 -m state --state NEW -j LOG --log-level warning --log-prefix 'Attempted to initiate a connection from a local process' --log-uid #block all with log
#iptables -t filter -I OUTPUT 1 -p udp -m multiport --ports 80,443 -j ACCEPT #filter exception
sudo iptables -P FORWARD DROP

# Avahi daemon
#sudo service avahi-daemon stop #avahi-daemon

# No cups
sudo cupsctl -E --no-remote-any
sudo service cups-browsed stop
sudo systemctl cupsd
sudo systemctl disable org.cups.cupsd

# Nftables
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
sudo nft add rule inet filter input ct state invalid drop #Drop any invalid traffic:
sudo nft add rule inet filter input ip protocol icmp icmp type echo-request ct state new accept #New echo requests (pings) will be accepted:
sudo nft add rule inet filter input ip protocol udp ct state new jump UDP #New upd traffic will jump to the UDP chain:
sudo nft add rule inet filter input ip protocol tcp tcp flags \& \(fin\|syn\|rst\|ack\) == syn ct state new jump TCP #New tcp traffic will jump to the TCP chain:
#Reject all traffic that was not processed by other rules:
sudo nft add rule inet filter input ip protocol udp reject
sudo nft add rule inet filter input ip protocol tcp reject with tcp reset
sudo nft add rule inet filter input counter reject with icmp type prot-unreachable

# Rootkit checking and Audits (see at the EOF)
# Antivirus and Cleaners
sudo pacman -S clamav bleachbit --noconfirm --needed

### Tweaks ###
# .bashrc
mv ~/.bashrc ~/.previous-bashrc
wget https://raw.githubusercontent.com/abueesp/Scriptnstall/master/.bashrc
sudo pacman -S onboard --noconfirm --needed #Virtual keyboard

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
sudo pacman -S arch-audit pacgraph pacutils --noconfirm --needed #personal aliases prefered over pacman-contrib

# PKGtools
sudo pacman -S pkgdiff --noconfirm --needed
git clone https://github.com/graysky2/lostfiles #Script that identifies files not owned and not created by any Arch Linux package.
cd lostfiles
make && sudo make install
cd ..
sudo rm -r lostfiles
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
#alias kalifyarch='printf "[archstrike] \n Server = https://mirror.archstrike.org/\$arch/\$repo/ " | sudo tee -a /etc/pacman.conf && sudo pacman-key --recv-keys 9D5F1C051D146843CDA4858BDE64825E7CBC0D51 && sudo pacman-key --finger 9D5F1C051D146843CDA4858BDE64825E7CBC0D51 && sudo pacman-key --lsign-key 9D5F1C051D146843CDA4858BDE64825E7CBC0D51'
#alias haskellfyarch='printf "[haskell-core] \n Server = http://xsounds.org/~haskell/core/\$arch " | sudo tee -a /etc/pacman.conf && sudo pacman-key --recv-keys F3104992EBF24EB872B97B9C32B0B4534209170B && sudo pacman-key --finger F3104992EBF24EB872B97B9C32B0B4534209170B && sudo pacman-key --lsign-key F3104992EBF24EB872B97B9C32B0B4534209170B && Haskwell WAIs: Yesod Framework brings Wrap Server. It is better than Happstack. For small projects try Scotty that also comes with Wrap, or maybe Snaps snaplets"'
#alias rubifyarch='printf "[quarry] \n Server = https://pkgbuild.com/~anatolik/quarry/x86_64/ " | sudo tee -a /etc/pacman.conf && echo "This repo has not key!"'

# AUR-helpers and repositories https://wiki.archlinux.org/index.php/AUR_helpers
git clone https://aur.archlinux.org/aurman.git #Aurman
cd aurman
makepkg -si --noconfirm --needed
cd ..
sudo rm -r aurman

#Deb packages
wget https://raw.githubusercontent.com/helixarch/debtap/master/debtap
echo "d9d40c88a401a33239880280ec9ec11e737cbbdc66e7830143c3b363fa8527fa8168ad708fba87bba0664fdda281a786fdf5a66e9f1e15be29ebb4d8bb157352  debtap" > debtap.txt
sha512sum -c debtap.txt 2>&1 | grep 'OK\|coincide'
if [ $? -eq 0 ] then
	echo "GOOD SHA 512"
	sudo chmod +x debtap
	sudo mv debtap /bin/debtap
else
	echo "BAD SHA 512"
	exit
fi

#Fixing wall
sudo rm /usr/bin/wall
sudo touch /usr/bin/wall
printf "echo 'Active receivers'
sudo ls /dev/pts/
read -p 'Introduce receivers separated by commas. Write nothing for everyone: ' ptslist
ptsnumbers=\$(echo \$ptslist | sed 's/,/ /g')
if [ -z \$ptsnumbers ]; then
    read -p 'Introduce text message or message path to send to everyone: ' ptsmessage
    if [ ! -f \$ptsmessage ]; then
        for pts in \$(ls /dev/pts/); do
            ptspath='/dev/pts/'\$pts
            echo \$ptsmessage > \$ptspath
        done
    else
        for pts in \$(ls /dev/pts/); do
            ptspath='/dev/pts/'\$pts
            echo \$ptsmessage > \$ptspath
        done
    fi
else
    read -p 'Introduce text message or message path to send to '\$ptsnumbers' :' ptsmessage
    if [ ! -f \$ptsmessage ]; then
        for pts in \$ptsnumbers; do
            ptspath='/dev/pts/'\$pts
            echo \$ptsmessage > \$ptspath
        done
    else
        for pts in \$ptsnumbers; do
            ptspath='/dev/pts/'\$pts
            cat \$ptsmessage > \$ptspath
        done
    fi
fi" | sudo tee -a /usr/bin/wall
sudo chmod +x /usr/bin/wall

# Search tools
gpg2 --keyserver ha.pool.sks-keyservers.net --recv-keys 465022E743D71E39 #for mlocate
sudo pacman -S mlocate recoll the_silver_searcher --noconfirm --needed #find locate
aurman -S tag-ag --noconfirm
printf 'tag() {
command tag "$@"
source /tmp/tag_aliases}
alias ag=tag' | tee -a ~/.bashrc
if [ ! -f /home/$USER/.recoll/recoll.conf ]; then
    mkdir /home/$USER/.recoll
    cp /usr/share/recoll/examples/recoll.conf /home/$USER/.recoll/recoll.conf
fi
vim -c ":%s.topdirs = / ~.topdirs = / ~.g" -c ":wq" /home/$USER/.recoll/recoll.conf
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
alsactl store

# Fixing bugs
# sudo pacman -S deepin-api --noconfirm -needed

# Sandboxing tools
# Namespaces tools: It limits what the app can see using pid, net, mnt, uts, ipc and user spaces. (alike cgroups, which limits how much can use, using memory, cpu, network, i/o, and other resources)
#Firejail
sudo pacman -S firejail --noconfirm --needed #Firejail is a SUID program that restricts the running environment of applications using Linux namespaces and seccomp-bpf.
sudo pacman -S xorg-server-xephyr --noconfirm --needed #Nested X11 better than Xnest
sudo vim -c ":%s/\# force-nonewprivs no/force-nonewprivs yes/g" -c ":wq" /etc/firejail/firejail.config #no setuid
RESOLUTION=$(xdpyinfo | awk '/dimensions/{print $2}')
sudo vim -c ":%s/\# xephyr-screen 640x480/xephyr-screen $RESOLUTION/g" -c ":wq" /etc/firejail/firejail.config #size
sudo vim -c ":%s/\# xephyr-extra-params -keybd ephyr,,,xkbmodel=evdev/xephyr-extra-params -keybd ephyr,,,xkbmodel=evdev -resizeable -audit 5/g" -c ":wq" /etc/firejail/firejail.config #ephyr keyboard audit

echo "if [ -z '$1' ]"| tee -a ix
echo "	then"| tee -a ix
echo "	ljail=2"| tee -a ix
echo "else"| tee -a ix
echo "	ljail=$(echo '2*$1' | bc)"| tee -a ix
echo "fi"| tee -a ix
echo "X2=$(firemon --x11 | awk -v ljail=$ljail 'FNR==$ljail{print \$0}' | awk '{print \$2}')" | tee -a ix
echo 'xclip -selection clip -o -display :0 | xclip -selection clip -i -display "$X2"' | tee -a ix
sudo chmod +x ix
sudo mv ix /bin/ix
echo "if [ -z '$1' ]"| tee -a ox
echo "	then"| tee -a ox
echo "	ljail=2"| tee -a ox
echo "else"| tee -a ox
echo "	ljail=$(echo '2*$1' | bc)"| tee -a ox
echo "fi"| tee -a ox
echo "X2=$(firemon --x11 | awk -v ljail=$ljail 'FNR==$ljail{print \$0}' | awk '{print \$2}')" | tee -a ox
echo 'xclip -selection clip -o -display "$X2" | xclip -selection clip -i -display :0' | tee -a ox
sudo chmod +x ox
sudo mv ox /bin/ox
sudo pacman -S xclip xbindkeys --noconfirm --needed
xbindkeys --defaults > ~/.xbindkeysrc
vim -c ":%s/\# set directly keycode (here control + f with my keyboard)/\# xclip input/g" -c ":wq" ~/.xbindkeysrc #introducing ix over xterm
vim -c ":45,47s/xterm/ix/" -c ":wq" ~/.xbindkeysrc
vim -c ":%s/c:41 + m:0x4/alt + i/g" -c ":wq" ~/.xbindkeysrc
vim -c ":%s/\# specify a mouse button/\# xclip output/g" -c ":wq" ~/.xbindkeysrc #introducing ox over xterm
vim -c ":49,51s/xterm/ox/" -c ":wq" ~/.xbindkeysrc
vim -c ":%s/control + b:2/alt + o/g" -c ":wq" ~/.xbindkeysrc


#Bubblewrap
sudo pacman -S bubblewrap --noconfirm --needed #bubblewrap works by creating a new, completely empty, mount namespace where the root is on a tmpfs that is invisible from the host, and will be automatically cleaned up when the last process exits.
wget https://raw.githubusercontent.com/projectatomic/bubblewrap/master/demos/bubblewrap-shell.sh
sudo chmod +x bubblewrap-shell.sh
sudo mv bubblewrap-shell.sh bwrapsh

# Containerization tools: less secure as they share kernel and hardware (not a real virtual machine), faster, more portable
#Chroot/Proot/Fakeroot: A chroot is an operation that changes the apparent root directory for the current running process and their children. A program that is run in such a modified environment cannot access files and commands outside that environmental directory tree. This modified environment is called a chroot jail.  Proot may be used to change the apparent root directory (all files are owned by the user on the host) and use mount --bind without root privileges (used for running programs built for a different CPU architecture). Fakeroot can be used to simulate a chroot as a regular user.
sudo pacman -S fakeroot --noconfirm --needed
#Spawn: systemd-nspawn is like the chroot command, but it is a chroot on steroids: it fully virtualizes the file system hierarchy, the process tree, various IPC subsystems and the host and domain name. systemd-nspawn limits access to various kernel interfaces in the container to read-only, such as /sys, /proc/sys or /sys/fs/selinux.
#ZeroVM is a scalable and portable container based on Google Native Client useful when you are having massive and parallel data inputs that need to be statically verified to be "safe" before used.
#LXC unpriviledged containerization provides kernel namespaces that has its own CPU, memory, block I/O, network, etc. under the resource control mechanism of kernel (cgroups). Seccomp included, apparmor and SElinux compatible.
sudo pacman -S lxc arch-install-scripts --noconfirm --needed
#LXD, a container system making use of LXC containers made by Canonical and specialized in deploying Linux distros.
#Docker a container system making written in Go that use LXC containers (among others) by Docker Inc (but the Community Version may be fully open source) and specialized in deploying apps (one in each container, including the one with the distro base image). It adds syntatic sugar, enabling image management, and providing deployment services, specially through third party apps. It also has  tools to set up virtual container hosts (Machine), orchestrate multiple services in containers linked together in a single stack (Compose yaml file), and orchestate your containers|tasks as a cluster (Swarm).
aurman docker https://docs.docker.com/engine/security/ https://wiki.archlinux.org/index.php/docker
#Kubernetes is a container orchestration system for Docker (containers are called services here, aggruped in nodes) made by Google but today managed by the Linux Foundation (but may be fully open source) that is more extensible than Docker Swarm. It uses pods, which have 1 or more containers, and uses Elasticsearch/Kibana (ELK) for logs within the container, Heapster/Grafana/Influx for monitoring in the container and Sysdig cloud integration.
aurman -S kubernetes --noconfirm --needed
#FreeBSD Jails (only with Pacbsd but discontinued 2017). FreeBSD's LXC with zfs compatibility, network isolation, daemon included in the kernel, and better default policies.
#Clear containers. It uses Intel VT-x. One container per Clear Linux VM wrapped with a specially-optimized copy of the Linux OS. Compatible with KVM and Docker with VT if using VMCS shadowing as a technology that accelerates nested virtualization of VMMs.
#Linux-VServer. It is a VPS implementation  by adding virtualization capabilities to the Linux kernel (host).
https://wiki.archlinux.org/index.php/Arch_Linux_VPS
#UML UserMode Linux (only for Linux)
https://wiki.archlinux.org/index.php/User-mode_Linux

# Emulation tools: Enables one host computer system to behave like another guest computer system
sudo pacman -S qemu qemu-arch-extra --noconfirm --needed

# Virtualization tools: governed by a hypervisor, enforce data isolation in hardware HVM, most secure, slower, less portable
#VMWare is the VM from Dell. Fully closed source and does not allow OSX outside Mac.
#Lguest: Linux kernel paravirtualization hypervisor. Lguest32 was introduced in kernel version 2.6.23 in 2007 and removed in kernel version 4.14 in 2017). 10x faster than basic qemu, and 100x faster than a real boot. Lguest64 was introduced on 2007 https://lwn.net/Articles/248189/ but most advanced still https://github.com/psomas/lguest64
#Xen: #Full and paravirtualization
#Virtualbox + Vagrant: Most compatible (except for Xen, which allows paravirtualization). It's from Oracle and has closed USB drivers.
pacman -Si linux
sudo pacman -S linux-headers --noconfirm --needed
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
vboxmanage storageattach myvm --storagectl IDE --port 0 --device 0 --type dvddrive --medium "/usr/share/VBoxGuestAdditions_$var1.iso"
#KVM, Qemu Kernel VM. Most secure. Mandatory Access Control and SELinux. It requires that the processor support Intel-VT or AMD-VT extensions, and that those extensions are enabled in the BIOS.
echo "Enable kvm to virtualize"

### Emacs ###
sudo pacman -S emacs --noconfirm --needed
sudo pacman -S git --noconfirm --needed
git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d
cd ~/.emacs.d
git clone https://github.com/EnigmaCurry/emacs/find/ancient-history
wget https://github.com/ethereum/emacs-solidity/blob/master/solidity-mode.el
wget https://melpa.org/packages/vyper-mode-20180707.1235.el
echo 'Carga los elementos de emacs con (add-to-list load-path "~/.emacs.d/") + (load "myplugin.el")' >> README
cd ..


### Vim ###
sudo pacman -S vim --noconfirm --needed
sudo pacman -S ctags cscope --noconfirm --needed
sudo pacman -S git --noconfirm --needed
git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime
sh ~/.vim_runtime/install_awesome_vimrc.sh

if [ -e "/home/$USER/.vim_runtime/vimrcs/basic.vim" ];
	then
		VIMRC=/home/$USER/.vim_runtime/vimrcs/basic.vim
	else
		VIMRC=.vimrc
fi
echo "VIMRC=$VIMRC" | tee -a ~/.bashrc

echo ' ' | tee -a "$VIMRC"
echo '\" => Commands' | tee -a "$VIMRC"
echo ":command! Vb exe \"norm! \\<C-V>" | tee -a "$VIMRC" #Visual column
echo "nnoremap <C-UP> :<c-u>execute 'move -1-'. v:count1<cr>" | tee -a "$VIMRC"  #Quickly move current line up
echo "nnoremap <C-DOWN> :<c-u>execute 'move +'. v:count1<cr>" | tee -a "$VIMRC" #Quickly move current line down
echo "nnoremap <C-space> :<c-u>put =repeat(nr2char(10), v:count1)<cr>" | tee -a "$VIMRC" #Quickly add blank line, better than ":nnoremap <C-O> o<Esc>"
echo "nnoremap <C-q> :<c-u><c-r><c-r>='let @'. v:register .' = '. string(getreg(v:register))<cr><c-f><left>" | tee -a "$VIMRC" #Quickly edit macro
echo "nnoremap <C-a> :%y+" | tee -a "$VIMRC" #Quickly select all, better than "nnoremap <C-a> gg"+yG"
echo "set autoindent" | tee -a "$VIMRC"
echo "set paste" | tee -a "$VIMRC"
echo "set mouse=a" | tee -a "$VIMRC"
echo "set undofile" | tee -a "$VIMRC"
echo "set clipboard=unnamedplus" | tee -a "$VIMRC"

echo ' ' | tee -a "$VIMRC"
echo '\" => Reticle' | tee -a "$VIMRC"
echo ":set cursorcolumn" | tee -a "$VIMRC"
echo ":set cursorline" | tee -a "$VIMRC"
echo ":set relativenumber" | tee -a "$VIMRC"

echo ' ' | tee -a "$VIMRC"
echo '\" => Ctags' | tee -a "$VIMRC"
echo "set tags+=~/.vim/ctags/c"  | tee -a "$VIMRC"
echo "set tags+=~/.vim/ctags/c++"  | tee -a "$VIMRC"

echo ' ' | tee -a "$VIMRC"
echo '\" => Arrow keys' | tee -a "$VIMRC"
echo "nnoremap <silent> <ESC>OA <UP>" | tee -a "$VIMRC"
echo "nnoremap <silent> <ESC>OB <DOWN>" | tee -a "$VIMRC"
echo "nnoremap <silent> <ESC>OC <RIGHT>" | tee -a "$VIMRC"
echo "nnoremap <silent> <ESC>OD <LEFT>" | tee -a "$VIMRC"
echo "inoremap <silent> <ESC>OA <UP>" | tee -a "$VIMRC"
echo "inoremap <silent> <ESC>OB <DOWN>" | tee -a "$VIMRC"
echo "inoremap <silent> <ESC>OC <RIGHT>" | tee -a "$VIMRC"
echo "inoremap <silent> <ESC>OD <LEFT>" | tee -a "$VIMRC"

echo ' ' | tee -a "$VIMRC"
echo '\" => Ctrl+Shift+c/p to copy/paste outside vim' | tee -a "$VIMRC"
echo "nnoremap <C-S-c> +y" | tee -a "$VIMRC"
echo "vnoremap <C-S-c> +y" | tee -a "$VIMRC"
echo "nnoremap <C-S-p> +gP" | tee -a "$VIMRC"
echo "vnoremap <C-S-p> +gP" | tee -a "$VIMRC"

echo ' ' | tee -a "$VIMRC"
echo '\" => Macros' | tee -a "$VIMRC"
function sendtovimrc(){
echo "let @$key='$VIMINSTRUCTION'" | tee -a "$VIMRC"
#please note the double set of quotes
}
key="p"
VIMINSTRUCTION="isudo pacman -S  --noconfirm --needed\<esc>4bhi"
sendtovimrc
key="y"
VIMINSTRUCTION="iaurman -S  --noconfirm --needed\<esc>4bhi"
sendtovimrc
key="a"
VIMINSTRUCTION="iaurman -S  --noconfirm --needed\<esc>4bhi"
sendtovimrc

#ag on Ack plugin
printf "if executable('ag')
  let g:ackprg = 'ag --vimgrep'
  :cnoreabbrev ag Ack
endif"  | tee -a "$VIMRC"

#PATHOGENFOLDER="~/.vim/build"
if [ -e "/home/$USER/.vim_runtime/sources_forked" ];
	then
		PATHOGENFOLDER="~/.vim_runtime/sources_forked"
elif [ -e "/home/$USER/.vim/sources_forked" ];
	else
		PATHOGENFOLDER="~/.vim/sources_forked"
else
	echo "No pathogen folder found"
fi
echo "PATHOGENFOLDER=$PATHOGENFOLDER" | tee -a ~/.bashrc
echo "alias pathogen=\"read -p 'Name of the plugin:' PLUGINNAME && read -p 'Plugin Git link:' PLUGINGIT && git clone $PLUGINGIT $PATHOGENFOLDER/$PLUGINNAME\"" | tee -a ~/.bashrc
echo 'alias viminstallplugin="pathogen"' | tee -a ~/.bashrc

wget http://cscope.sourceforge.net/cscope_maps.vim
echo "set timeoutlen=4000" | tee -a cscope_maps.vim
echo "set ttimeout" | tee -a cscope_maps.vim
echo "#sudo find / -type f -print | grep -E '\.c(pp)?|h)$' > cscope.files && cscope -bq" | tee -a cscope_maps.vim
git clone https://github.com/tpope/vim-sensible "$PATHOGENFOLDER"/vim-sensible
git clone https://github.com/ocaml/merlin "$PATHOGENFOLDER"/merlin
git clone https://github.com/OmniSharp/omnisharp-vim $PATHOGENFOLDER/omnisharp-vim && cd "$PATHOGENFOLDER"/omnisharp-vim && git submodule update --init --recursive && cd server && xbuild && cd
#git clone https://github.com/rhysd/vim-crystal/ "$PATHOGENFOLDER"/vim-crystal
#git clone https://github.com/venantius/vim-eastwood.git "$PATHOGENFOLDER"/vim-eastwood
git clone https://github.com/rust-lang/rust.vim "$PATHOGENFOLDER"/rust
git clone https://github.com/kballard/vim-swift.git "$PATHOGENFOLDER"/swift
git clone --recursive https://github.com/python-mode/python-mode "$PATHOGENFOLDER"/python-mode
git clone https://github.com/eagletmt/ghcmod-vim "$PATHOGENFOLDER"/ghcmod-vim
git clone https://github.com/eagletmt/neco-ghc "$PATHOGENFOLDER"/neco-ghc
git clone https://github.com/ahw/vim-hooks "$PATHOGENFOLDER"/vim-hooks
echo ":nnoremap gh :StartExecutingHooks<cr>:ExecuteHookFiles BufWritePost<cr>:StopExecutingHooks<cr>" | sudo tee -a /usr/share/vim/vimrc
echo ":noremap ghl :StartExecutingHooks<cr>:ExecuteHookFiles VimLeave<cr>:StopExecutingHooks<cr>" | sudo tee -a /usr/share/vim/vimrc
git clone https://github.com/sheerun/vim-polyglot "$PATHOGENFOLDER"/vim-polyglot
echo "syntax on" | sudo tee -a /usr/share/vim/vimrc
git clone https://github.com/scrooloose/nerdcommenter "$PATHOGENFOLDER"/nerdcommenter
git clone https://github.com/sjl/gundo.vim "$PATHOGENFOLDER"/gundo
echo " " | tee -a "$VIMRC"
echo "nnoremap <F5> :GundoToggle<CR>" | tee -a "$VIMRC"
git clone https://github.com/Shougo/neocomplcache.vim "$PATHOGENFOLDER"/neocomplcache
echo "let g:neocomplcache_enable_at_startup = 1" | tee -a "$VIMRC"
git clone https://github.com/easymotion/vim-easymotion "$PATHOGENFOLDER"/vim-easymotion
git clone https://github.com/spf13/PIV "$PATHOGENFOLDER"/PIV
git clone https://github.com/tpope/vim-surround "$PATHOGENFOLDER"/vim-surround
wget https://raw.githubusercontent.com/xuhdev/vim-latex-live-preview/master/plugin/latexlivepreview.vim -O "$PATHOGENFOLDER"/latexlivepreview.vim
git clone https://github.com/vim-latex/vim-latex "$PATHOGENFOLDER"/vim-latex

git clone https://github.com/tomtom/tlib_vim.git "$PATHOGENFOLDER"/tlib_vim
git clone https://github.com/MarcWeber/vim-addon-mw-utils.git "$PATHOGENFOLDER"/vim-addon-mw-utils
git clone https://github.com/garbas/vim-snipmate.git "$PATHOGENFOLDER"/vim-snipmate
git clone https://github.com/honza/vim-snippets.git "$PATHOGENFOLDER"/vim-snippets
echo " " | tee -a "$VIMRC"
echo "nnoremap <C-R><C-T> <Plug>snipMateTrigger" | tee -a "$VIMRC"
echo "nnoremap <C-R><C-G> <Plug>snipMateNextOrTrigger" | tee -a "$VIMRC"
mkdir -p "$PATHOGENFOLDER"/vim-snippets/snippets
cd "$PATHOGENFOLDER"/vim-snippets/snippets
git clone https://github.com/Chalarangelo/30-seconds-of-code/
mv 30-seconds-of-code/test 30secJavaScript
sudo rm -r 30-seconds-of-code
cd 30secJavaScript
find . -iname "*js*" -exec rename .js .snippet '{}' \;
cd ..
git clone https://github.com/kriadmin/30-seconds-of-python-code
mv 30-seconds-of-python-code/test 30secPython3
sudo rm -r 30-seconds-of-python-code
cd 30secPython3
find . -iname "*py*" -exec rename .py .snippet '{}' \;
cd ..
cd

git clone https://github.com/maralla/completor.vim "$PATHOGENFOLDER"/completor
sudo -H pip install jedi #completor for python
echo "let g:completor_python_binary = '/usr/lib/python*/site-packages/jedi'" | tee -a "$VIMRC"
git clone https://github.com/ternjs/tern_for_vim "$PATHOGENFOLDER"/tern_for_vim
echo "let g:completor_node_binary = '/usr/bin/node'" | tee -a "$VIMRC"
echo "let g:completor_clang_binary = '/usr/bin/clang'" | tee -a "$VIMRC" #c++
git clone https://github.com/nsf/gocode "$PATHOGENFOLDER"/completor #go
echo "let g:completor_gocode_binary = '$PATHOGENFOLDER/gocode'"
git clone https://github.com/maralla/completor-swift "$PATHOGENFOLDER"/completor-swift #swift
cd "$PATHOGENFOLDER"/completor-swift
make
cd
echo "let g:completor_swift_binary = '$PATHOGENFOLDER/completor-swift'" | tee -a "$VIMRC"

#Vim portability for ssh (sshrc)
wget https://raw.githubusercontent.com/Russell91/sshrc/master/sshrc && sudo chmod -R 600 sshrc && chmod +x sshrc && sudo mv sshrc /usr/local/bin

vimfunctions(){
echo "### Tools ###"
echo "cscope: Browsing tool similar to ctags, Ctrl+\ "
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
echo "vim-latex-live-preview: preview for latex (:LLPStartPreview)"
echo "vim-latex-suite: vim latex suite with editing, compiling, viewing, folding, packages, dictionary, templates, macros tools (:help latex-suite)"
echo ""
echo "### Indenters ###"
echo "vim-indent-object: Python indenter (ai and ii and al and il)"
echo ""
echo "### Syntax ###"
echo "vim-polyglot: (you can deactivate some using echo \"let g:polyglot_disabled = ['css']\"| sudo tee -a /usr/share/vim/vimrc) syntax, indent, ftplugin and other tools for ansible apiblueprint applescript arduino asciidoc blade c++11 c/c++ caddyfile cjsx clojure coffee-script cql cryptol crystal css cucumber dart dockerfile elixir elm emberscript emblem erlang fish git glsl gnuplot go graphql groovy haml handlebars haskell haxe html5 i3 jasmine javascript json  jst jsx julia kotlin  latex  less  liquid  livescript  lua  mako  markdown  mathematica nginx  nim  nix  objc ocaml octave opencl perl pgsql php plantuml powershell protobuf pug puppet purescript python-compiler python  qml  r-lang racket  ragel raml rspec ruby rust sbt scala scss slim solidity stylus swift sxhkd systemd terraform textile thrift tmux tomdoc toml twig typescript vala vbnet vcl vm vue xls yaml yard"
echo ""
echo "### Snippets ###"
echo "Ultisnips: The ultimate snippet solution for Vim (needs Python, alike snipmate): :helptags ~/.vim/ultisnips_rep/doc :help UltiSnips"
echo "30 seconds of X: Javascript and Python3 snippets"
echo ""
echo "### Syntastics and linters ###"
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
echo vimfunctions >> "$PATHOGENFOLDER"/README

##Git
sudo pacman -S git --noconfirm --needed
git config --global credential.helper cache
# Set git to use the credential memory cache
git config --global credential.helper 'cache --timeout=3600'
# Set the cache to timeout after 1 hour (setting is in seconds)
read -p "Please set your git username (by default $USER): " gitusername
gitusername="${gitusername=$USER}"
git config --global user.name "$gitusername"
read -p "Please set your git mail  (by default $USER@localhost): " gitmail
gitmail="${gitmail=$USER@localhost}"
git config --global user.email "$gitmail"
read -p "Please set your core editor (by default vim): " giteditor
giteditor="${giteditor=vim}"
git config --global core.editor "$giteditor"
read -p "Please set your gitdiff (by default vimdiff): " gitdiff
gitdiff="${gitdiff=vimdiff}"
git config --global merge.tool "$gitdiff"
read -p "Do you prefer to user gpg or gpg2? (by default gpg2): " $gpgg
gpgg="${gpgg=gpg2}"
read -p "Do you want to create a new gpg key for git?: " creategitkey
creategitkey="${creategitkey=N}"
case "$creategitkey" in
    [yY][eE][sS]|[yY])
        $gpgg --full-gen-key --expert
	$gpgg --list-keys
        ;;
    *)
        echo "So you already created a key"
	$gpgg --list-keys
        ;;
esac
read -p "Introduce the key id number (and open https://github.com/settings/keys or your personal server alternative): " keyusername
git config --global user.signingkey $keyusername
git config --global commit.gpgsign true
git config --global gpg.program $gpgg
git config --list
time 5
echo "Here you are an excellent Git cheatsheet https://raw.githubusercontent.com/hbons/git-cheat-sheet/master/preview.png You can also access as gitsheet"
echo "If you get stuck, run ‘git branch -a’ and it will show you exactly what’s going on with your branches. You can see which are remotes and which are local."
echo "Do not forget to add a newsshkey or clipboard your mysshkey or mylastsshkey (if you switchsshkey before) and paste it on Settings -> New SSH key and paste it there."

### Tmux ###
sudo pacman -S tmux  --noconfirm --needed
sudo rm ~/.tmux.conf.bak
cp ~/.tmux.conf ~/.tmux.bak
wget https://raw.githubusercontent.com/abueesp/Scriptnstall/master/.tmux.conf
TMUXPLG="$HOME/.tmuxplugins"
mkdir $TMUXPLG
cd $TMUXPLG
git clone https://github.com/tmux-plugins/tmux-resurrect #session prefix + Ctrl-s - saveprefix + Ctrl-r - restore
echo "run-shell $TMUXPLG/tmux-resurrect/resurrect.tmux" | tee -a $HOME/.tmux.conf
git clone https://github.com/tmux-plugins/tmux-continuum #continuous saving of tmux environmentautomatic tmux start when computer/server is turned onautomatic restore when tmux is started
echo "run-shell $TMUXPLG/tmux-continuum/continuum.tmux" | tee -a $HOME/.tmux.conf
git clone https://github.com/tmux-plugins/tmux-yank #prefix–y — copies text from the command line to the clipboard.
echo "run-shell $TMUXPLG/tmux-yank/yank.tmux" | tee -a $HOME/.tmux.conf
git clone https://github.com/tmux-plugins/tmux-net-speed #monitor all interfaces Shows value in either MB/s, KB/s, or B/s
echo "run-shell $TMUXPLG/tmux-net-speed/net_speed.tmux" | tee -a $HOME/.tmux.conf
git clone https://github.com/tmux-plugins/tmux-sidebar #prefix + Tab - toggle sidebar with a directory treeprefix + Backspace - toggle sidebar and move cursor to it (focus it)
echo "run-shell $TMUXPLG/tmux-sidebar/sidebar.tmux" | tee -a $HOME/.tmux.conf
git clone https://github.com/tmux-plugins/tmux-pain-control #pane control prefix + [C-]h/j/k/l/h Resizing shift + h/j/k/l/h Splitting prefix + \|_ Swapping prefix + <>
echo "run-shell $TMUXPLG/tmux-pain-control/pain-control.tmux" | tee -a $HOME/.tmux.conf
git clone https://github.com/tmux-plugins/tmux-sensible #A set of tmux options that should be acceptable to everyone.
echo "run-shell $TMUXPLG/tmux-sensible/sensible.tmux" | tee -a $HOME/.tmux.conf
cd ..

### Tools ###
#Network tools
sudo pacman -S traceroute nmap arp-scan conntrack-tools --noconfirm --needed
aurman -S wireshark-cli wireshark-common wireshark-qt ostinato --noconfirm --needed
sudo pacman -S hcxtools hcxdumptool hashcat --noconfirm --needed
sudo setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' /usr/sbin/dumpcap #wireshark permissions
sudo  gpasswd -a $USER wireshark
aurman -S slurm nethogs --noconfirm #tops

#Backups
sudo pacman -S duplicity deja-dup borg --noconfirm --needed

#Disk tools
sudo pacman -S gparted hdparm --noconfirm --needed
aurman deskcon filecast obexfs --noconfirm --needed #filesharing: wifiserver with apk, qrwifi, bluetooth
sudo pacman -S baobab ncdu --noconfirm --needed #prefered over QDirStat which is prefered over gdmap

#Office
wget https://raw.githubusercontent.com/abueesp/Scriptnstall/master/.bc #My programmable calc
sudo pacman -S libreoffice grc unoconv detox pandoc hunspell plotutils --noconfirm --needed #Text tools
aurman -S evince-no-gnome --noconfirm --needed
sudo pacman -S xmlstarlet jq datamash bc gawk mawk --noconfirm --needed #XML and jquery #wc join paste cut sort uniq
sudo pacman -S blender --noconfirm --needed
sudo pacman -S krita --noconfirm --needed
aurman -S bashblog-git --noconfirm #blog
#aurman -S ganttproject --noconfirm #gantt
wget http://staruml.io/download/releases/StarUML-3.0.2-x86_64.AppImage #uml
sudo chmod +x StarUML*.AppImage
sudo mv StarUML*.AppImage /bin/staruml
sudo pacman -S gucharmap --noconfirm --needed #+200B

#Other tools
sudo pacman -S brasero archiso --noconfirm --needed
sudo pacman -S terminator tilix --noconfirm --needed
sudo pacman -S shellcheck rlwrap --noconfirm --needed
sudo pacman -S d-feet htop autojump iotop task atop vnstat at nemo ncdu tree recordmydesktop --noconfirm --needed
touch ~/.local/share/nemo/actions/compress.nemo_action
printf "[Nemo Action]
Active=true
Name=Compress...
Comment=compress %N
Exec=file-roller -d %F
Icon-Name=gnome-mime-application-x-compress
Selection=Any
Extensions=any;" | tee -a ~/.local/share/nemo/actions/extracthere.nemo_action
printf "[Nemo Action]
Active=true
Name=Extract here
Comment=Extract here
Exec=file-roller -h %F
Icon-Name=gnome-mime-application-x-compress
 #Stock-Id=gtk-cdrom
Selection=Any
Extensions=zip;7z;ar;cbz;cpio;exe;iso;jar;tar;tar;7z;tar.Z;tar.bz2;tar.gz;tar.lz;tar.lzma;tar.xz;" | tee -a ~/.local/share/nemo/actions/extracthere.nemo_action
REPEATVERSION=4.0.1
REPEATVER=4_0_1
wget https://github.com/repeats/Repeat/releases/download/v$REPEATVERSION/Repeat_$REPEATVER.jar
sudo mv Repeat_$REPEATVER.jar /usr/src/repeat.jar
sudo pacman -S jdk8-openjdk --noconfirm --needed
#echo 'alias repeatmouse="java -jar /usr/src/repeat.jar"' | tee -a ~/.bashrc
echo 'If the user blind consider to install a blindlector such as orca'
sudo pacman -S units dateutils --noconfirm --needed
sudo -H pip install when-changed #run a command (alert) when file is changed
wget https://gist.githubusercontent.com/Westacular/5996271/raw/147384089e72f4009f177cd2d5c089bb2d8e5934/birthday_second_counter.py
sudo mv birthday_second_counter.py /bin/timealive
sudo chmod +x /bin/timealive
sudo pacman -S colordiff kompare --noconfirm --needed
sudo pacman -S perl-image-exiftool --noconfirm --needed #image metadata
#echo 'alias repeatmouse="java -jar /usr/src/repeat.jar"' | tee -a ~/.bashrc
#echo 'alias matimg="exiftool -exif:all="' | tee -a ~/.bashrc
alias icecat="firejail --x11=xephyr /bin/./icecat --profile /opt/icecat/profiles"

### Browsers ###
#Flash
sudo pacman -Rc flashplugin pepper-flash --noconfirm
aurman -S lightspark-git --noconfirm --needed

#Qutebrowser
sudo pacman -S qutebrowser --noconfirm --needed #Better than luakit or lariza
mkdir -p ~/.local/share/qutebrowser/
mkdir -p ~/.local/share/qutebrowser/monkeyscripts/
wget https://github.com/ParticleCore/Iridium/raw/master/src/Userscript/Iridium.user.js -O ~/.local/share/qutebrowser/monkeyscripts/Iridium.user.js

#Firefox
sudo pacman -S firefox --noconfirm --needed
sudo pacman -S firefox-developer --noconfirm --needed
mkdir -p extensions
cd extensions
mkdir tools
cd tools
wget https://tridactyl.cmcaine.co.uk/betas/tridactyl-latest.xpi -O tridactyl.xpi
wget https://addons.mozilla.org/firefox/downloads/file/910464/tab_session_manager-3.1.0-an+fx-linux.xpi -O TabSessionManager.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/355192/addon-355192-latest.xpi -O MindTheTime.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/1843/addon-1843-latest.xpi -O Firebug.xpi
wget https://addons.mozilla.org/firefox/downloads/file/387220/text_to_voice-1.15-fx.xpi -O TextToVoice.xpi
wget https://addons.mozilla.org/firefox/downloads/file/393843/soundcloud_music_downloader-0.2.0-fx-linux.xpi -O Soundcloud.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/695840/addon-695840-latest.xpi -O FlashDebugger.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/3829/addon-3829-latest.xpi -O liveHTTPHeaders.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/3497/addon-3497-latest.xpi -O EnglishUSDict.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/409964/addon-409964-latest.xpi -O VideoDownloadHelper.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/export-to-csv/addon-364467-latest.xpi -O ExportTabletoCSV.xpi
wget https://addons.mozilla.org/firefox/downloads/file/769143/blockchain_dns-1.0.9-an+fx.xpi -O BlockchainDNS.xpi
#wget https://addons.mozilla.org/firefox/downloads/latest/perspectives/addon-7974-latest.xpi -O perspectivenetworknotaries.xpi
wget https://www.roboform.com/dist/roboform-firefox.xpi
cd ..
mkdir privacy
cd privacy
wget https://addons.mozilla.org/firefox/downloads/file/869616/tracking_token_stripper-2.1-an+fx.xpi GoogleTrackBlock.xpi
wget https://addons.mozilla.org/firefox/downloads/file/839942/startpagecom_private_search_engine.xpi #For others use OpenSearch
wget https://addons.mozilla.org/firefox/downloads/file/706680/google_redirects_fixer_tracking_remover-3.0.0-an+fx.xpi GoogleRedirectFixer.xpi
wget https://addons.mozilla.org/firefox/downloads/file/727843/skip_redirect-2.2.1-fx.xpi -O SkipRedirect.xpi
wget https://addons.mozilla.org/firefox/downloads/file/1003544/user_agent_switcher-1.2.1-an+fx.xpi -O UserAgentSwitcher.xpi
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
wget https://addons.mozilla.org/firefox/downloads/file/1035032/enterprise_policy_generator-3.1.0-an+fx.xpi -O PolicyGenerator.xpi
wget https://addons.mozilla.org/firefox/downloads/file/1030797/canvasblocker-0.5.2b-an+fx.xpi -O BlockCanvas.xpi
wget https://addons.mozilla.org/firefox/downloads/file/790214/umatrix-1.1.12-an+fx.xpi -O UMatrix.xpi
wget https://addons.mozilla.org/firefox/downloads/file/872067/firefox_multi_account_containers-6.0.0-an+fx-linux.xpi -O ProfileSwitcher.xpi
wget https://addons.mozilla.org/firefox/downloads/file/974835/copy_plaintext-1.8-an+fx.xpi -O CopyPlainText.xpi
wget https://addons.mozilla.org/firefox/downloads/file/860538/behind_the_overlay-0.1.6-an+fx.xpi -O BehindTheOverlay.xpi
wget https://addons.mozilla.org/firefox/downloads/file/966587/auto_tab_discard-0.2.8-an+fx.xpi -O AutoTabDiscardByMemory.xpi
wget https://addons.mozilla.org/firefox/downloads/file/969185/foxyproxy_standard-6.3-an+fx.xpi FoxyProxyStandard.xpi
cd ..
mkdir otherprivacy
cd otherprivacy
wget https://addons.mozilla.org/firefox/downloads/latest/certificate-patrol/addon-6415-latest.xpi -O certificate patrol.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/6196/addon-6196-latest.xpi -O PassiveRecon.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/521554/addon-521554-latest.xpi -O DecentralEyes.xpi
cd ..
mkdir github
cd github
wget https://addons.mozilla.org/firefox/downloads/file/976102/octolinker-4.18.1-fx.xpi
wget https://addons.mozilla.org/firefox/downloads/file/888344/octotree-2.4.6-an+fx.xpi
wget https://addons.mozilla.org/firefox/downloads/file/846406/codeflower-0.1.3-an+fx.xpi
wget https://addons.mozilla.org/firefox/downloads/file/880748/lovely_forks-3.3.0-an+fx.xpi -O LovelyForks
#wget https://addons.mozilla.org/firefox/downloads/file/974367/sourcegraph-1.7.18-an+fx.xpi
cd ..
mkdir othertools
cd othertools
wget https://addons.mozilla.org/firefox/downloads/latest/5791/addon-5791-latest.xpi -O FlagFox.xpi
wget https://addons.mozilla.org/en-US/firefox/downloads/latest/2109/addon-2109-latest.xpi -O FEBEBackups.xpi
#wget https://addons.mozilla.org/firefox/downloads/latest/363974/addon-363974-latest.xpi -O Lightbeam.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/tabletools2/addon-296783-latest.xpi -O TableTools2.xpi
wget https://addons.mozilla.org/firefox/downloads/file/1166965/violentmonkey-2.10.0-an+fx.xpi -O Violentmonkey.xpi
wget https://github.com/ParticleCore/Iridium/raw/master/src/Userscript/Iridium.user.js
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
wget https://addons.mozilla.org/firefox/downloads/file/140447/cryptofox-2.2-fx.xpi -O CryptoFox.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/copy-as-plain-text/addon-344925-latest.xpi -O CopyasPlainText.xpi
wget https://addons.mozilla.org/firefox/downloads/file/229626/sql_inject_me-0.4.7-fx.xpi
wget https://addons.mozilla.org/firefox/downloads/file/215802/rightclickxss-0.2.1-fx.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/3899/addon-3899-latest.xpi -O HackBar.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/wappalyzer/addon-10229-latest.xpi -O Wappanalyzer.xpi
wget https://addons.mozilla.org/firefox/downloads/latest/344927/addon-344927-latest.xpi -O CookieExportImport.xpi
wet https://addons.mozilla.org/firefox/downloads/file/204186/fireforce-2.2-fx.xpi -O FireForce.xpi
wget https://addons.mozilla.org/firefox/downloads/file/224182/csrf_finder-1.2-fx.xpi -O CsrfFinder.xpi
wget https://addons.mozilla.org/firefox/downloads/file/345004/live_http_headers_fixed_by_danyialshahid-0.17.1-signed-sm+fx.xpi
wget https://addons.mozilla.org/firefox/downloads/file/782839/recap-1.1.8-an+fx.xpi -O RECAPforsearchingUSLawDB.xpi
cd ..
cd ..

### START FIREFOX PREFERENCES ###
#Delete IDs
vim -c ':%s/user_pref("browser.newtabpage.activity-stream.impressionId".*//g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("toolkit.telemetry.cachedClientID".*;//g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("toolkit.telemetry.previousBuildID".*;//g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("browser.search.cohort".*;/user_pref("browser.search.cohort", "testcohort");/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js

#Stop giving-away data unnecessarily
rm -r ~/.mozilla/firefox/*.default/datareporting/*
rm -r ~/.mozilla/firefox/*.default/saved-telemetry-pings/
rm ~/.mozilla/firefox/*.default/SiteSecurityServiceState.txt
echo 'user_pref("privacy.popups.disable_from_plugins", 3);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
#vim -c ':%s/user_pref("browser.search.countryCode".*;//g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
#vim -c ':%s/user_pref("browser.search.region.*;//g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js #timezone
echo 'user_pref("privacy.resistFingerprinting", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("privacy.resistFingerprinting.block_mozAddonManager", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #deactivates caching in memory areas of the working memory
echo 'user_pref("privacy.donottrackheader.enabled", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("privacy.donottrackheader.value", 1);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("network.http.referer.spoofSource", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("privacy.trackingprotection.enabled", false);/user_pref("privacy.trackingprotection.enabled", true);/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
#vim -c ':%s/user_pref("places.history.expiration.transient_current_max_pages".*;/user_pref("places.history.expiration.transient_current_max_pages", 2);/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.sessionstore.privacy level", 2);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("network.cookie.cookieBehavior".*);/user_pref("network.cookie.cookieBehavior", 1);/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js #only cookies from the actual website, but no 3rd party cookies from other websites are accepted
vim -c ':%s/user_pref("network.cookie.lifetimePolicy".*);/user_pref("network.cookie.lifetimePolicy", 2);/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js #all cookie data is deleted at the end of the session or when closing the browser
#echo 'user_pref("media.navigator.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
#echo 'user_pref("media.peerconnection.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
#echo 'user_pref("media.getusermedia.browser.enabled ", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
#echo 'user_pref("media.getusermedia.audiocapture.enabled  ", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
#echo 'user_pref("media.getusermedia.screensharing.enabled ", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("geo.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.push.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
#echo 'user_pref("dom.push.connection.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.search.geoip.url", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.search.geoSpecificDefaults", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("app.update.lastUpdateTime.telemetry_modules_ping".*;/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("devtools.onboarding.telemetry.logged".*;/user_pref("devtools.onboarding.telemetry.logged", false;/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("devtools.telemetry.tools.opened.version".*;/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("devtools.remote.wifi.scan", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("toolkit.telemetry.reportingpolicy.firstRun".*;/user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("datareporting.healthreport.uploadEnabled".*;/user_pref("datareporting.healthreport.uploadEnabled", false);/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("app.normandy.first_run".*;/user_pref("app.normandy.first_run", false);/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("app.normandy.user_id".*;//g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("app.shield.optoutstudies".*;/user_pref("app.shield.optoutstudies", false);/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("beacon.enabled".*;/user_pref("beacon.enabled", false);/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.chrome.errorReporter.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.library.activity-stream.enabled ", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.newtabpage.activity-stream.prerender", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.newtabpage.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.ping-center.telemetry", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("app.update.lastUpdateTime.telemetry_modules_ping".*;//g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("browser.laterrun.bookkeeping.profileCreationTime".*;//g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.ping-center.telemetry", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.send_pings", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.send_pings.max_per_link", 0);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.ping-center.telemetry", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.startup.homepage", about:blank);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.startup.homepage_override.mstone", ignore);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.tabs.crashReporting.sendReport", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("datareporting.policy.dataSubmissionEnabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("datareporting.healthreport.uploadEnabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("device.sensors.*;//g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("device.sensors.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("device.sensors.*;//g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("pref.privacy.disable_button.view_passwords.*;/user_pref("pref.privacy.disable_button.view_passwords", false);/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("full-screen.api.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.webkitBlink.dirPicker.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.webkitBlink.dirPicker.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("marionette.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.serviceWorkers.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("extensions.getAddons.cache.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("network.allow-experiments", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("network.captive-portal-service.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("network.predictor.enable-prefetch", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("toolkit.telemetry.enabled.*;//g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("toolkit.telemetry.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("toolkit.telemetry.unified", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("experiments.activeExperiment", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("experiments.supported", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("experiments.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("experiments.activeExperiment", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("identity.fxaccounts.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #disables Firefox account and Sync service
echo 'user_pref("webextensions.storage.sync.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.uitour.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.urlbar.speculativeConnect.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.autofocus", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.zoom.siteSpecific", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("canvas.capturestream.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js

#DOM
echo 'user_pref("dom.ipc.plugins.reportCrashURL", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.enable_performance", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.enable_performance_observer", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.enable_performance_navigation_timing ", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.enable_resource_timing", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.event.clipboardevents.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.requestIdleCallback.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.w3c_pointer_events.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.w3c_touch_events.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.webdriver.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.animations-api.core.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.animations-api.element-animate.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.battery.enabled, false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.battery.enabled, false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
#echo 'user_pref("dom.gamepad.enabled, false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.indexedDB.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.mapped_arraybuffer.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.registerProtocolHandler.insecure.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.select_events.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.select_events.textcontrols.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.vibrator.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.webaudio.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.webkitBlink.dirPicker.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.webkitBlink.filesystem.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.ipc.processCount.webLargeAllocation", 1);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #no large memory areas are reserved for websites and> 1 additional, separate processes are started, which signal a larger memory requirement due to WASM or asm.js (eg web games, WASM and asm.js applications)
echo 'user_pref("dom.largeAllocationHeader.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #no large memory areas are reserved for websites and> 1 additional, separate processes are started, which signal a larger memory requirement due to WASM or asm.js (eg web games, WASM and asm.js applications)

#JS
echo 'user_pref("javascript.options.asmjs", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("javascript.options.baselineji", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("javascript.options.ion", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("javascript.options.wasm", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("javascript.options.wasm_baselinejit", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("javascript.options.wasm_ionjit", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("javascript.options.discardSystemSource", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("javascript.options.shared_memory", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("jsloader.shareGlobal", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js

#SSL #4 = TLS 1.3, 3 = TLS 1.2, 2 = TLS 1.1, 1 = TLS 1.0, 0 = SSL 3.0
echo 'user_pref("security.ssl.errorReporting.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("security.tls.version.max", 4);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("security.tls.version.min", 3);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.urlbar.trimURLs", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("network.http.altsvc.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("network.http.altsvc.oe", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("security.cert_pinning.enforcement_level", 2);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #0: PKP disabled, 1: "custom MITM" allowed (PKP is not applied to CA certificates imported by the user), 2. PKP is always applied
echo 'user_pref("security.insecure_connection_icon.enabled", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("ssecurity.pki.sha1_enforcement_level", 1);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #with 1, TLS certificates signed using SHA-1 are rejected or a warning appears, with 0 they are accepted
echo 'user_pref("security.remember_cert_checkbox_default_setting", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("security.ssl.disable_session_identifiers", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("security.ssl.require_safe_negotiation", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("security.ssl.treat_unsafe_negotiation_as_broken", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("security.tls.enable_0rtt_data", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("security.mixed_content.block_active_content", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("security.mixed_content.block_object_subrequest", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("security.mixed_content.block_display_content", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("security.mixed_content.upgrade_display_content", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js

#Isolate tabs
echo 'user_pref("privacy.firstparty.isolate", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("privacy.firstparty.isolate.restrict_opener_access", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("privacy.userContext.enabled", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("privacy.userContext.longPressBehavior", 2);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("privacy.userContext.ui.enabled", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("privacy.usercontext.about_newtab_segregation.enabled", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js

#Safer browsing
#echo 'user_pref("security.ssl.errorReporting.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #Check SSL
echo 'user_pref("browser.safebrowsing.allowOverride", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.safebrowsing.blockedURIs.enable", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("browser.safebrowsing.downloads.enabled", false);/user_pref("browser.safebrowsing.downloads.enabled", true);/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("browser.safebrowsing.downloads.remote.block_potentially_unwanted", false);/user_pref("browser.safebrowsing.downloads.remote.block_potentially_unwanted", true);/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("safebrowsing.downloads.remote.block_uncommon", false);/user_pref("safebrowsing.downloads.remote.block_uncommon", true);/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("safebrowsing.malware.enabled", false);/user_pref("safebrowsing.malware.enabled", true);/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("safebrowsing.phishing.enabled", false);/user_pref("safebrowsing.phishing.enabled", true);/g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.safebrowsing.blockedURIs.enabled", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.safebrowsing.debug", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.safebrowsing.reportMalwareMistakeURL", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.safebrowsing.reportPhishMistakeURL", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("urlclassifier.disallow_completions", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("urlclassifier.gethashnoise", 9);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("urlclassifier.gethash.timeout_ms", 3);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("urlclassifier.max-complete-age", 3600);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("dom.storage.default_quota", 1);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #DOM Storage and issues a warning if more than 1 Kb is to be saved
echo 'user_pref("offline-apps.quota.warn", 1);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.cache.memory.enable", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #deactivates caching in memory areas of the working memory
echo 'user_pref("extensions.getAddons.showPane", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
vim -c ':%s/user_pref("extensions.getAddons.cache.lastUpdate.*;//g' -c ":wq" ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("xpinstall.signatures.required", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("extensions.langpacks.signatures.required", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("extensions.pocket.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("extensions.screenshots.disabled", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("extensions.screenshots.upload-disabled", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("canvas.capturestream.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
#echo 'user_pref("clipboard.plainTextOnly", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #Addon xpi for this option
echo 'user_pref("full-screen-api.ignore-widgets", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("full-screen-api.pointer-lock.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("browser.fullscreen.autohide", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("layout.css.mix-blend-mode.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("layout.css.background-blend-mode.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("layout.css.visited_links_enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
#echo 'user_pref("media.autoplay.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
#echo 'user_pref("media.video_stats.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("media.webspeech.recognition.enable", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("media.webspeech.synth.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("network.auth.subresource-http-auth-allow", 0);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("network.ftp.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("network.http.redirection-limit", 2);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("network.http.spdy.allow-push", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("network.http.spdy.coalesce-hostnames", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("network.http.speculative-parallel-limit", 0);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
#echo 'user_pref("network.jar.block-remote-files", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("network.prefetch-next", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("network.predictor.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("network.predictor.enable-prefetch", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("security.csp.experimentalEnabled", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("security.family_safety.mode", 0);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("webgl.disabled", true);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #Problematic?
echo 'user_pref("security.xpconnect.plugin.unrestricted", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js
echo 'user_pref("layout.css.prefixes.animations", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js

#DNS
echo 'user_pref("unetwork.trr.bootstrapAddress", 1.0.0.1);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #Cloudfare
echo 'user_pref("network.trr.mode", 3);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #Only cloudfare
echo 'user_pref("network.trr.uri", https://cloudflare-dns.com/dns-query);' | tee -a ~/.mozilla/firefox/*.default/prefs.js

#Searches and forms
#echo 'user_pref("browser.autofocus", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #already in stop giving-away data
echo 'user_pref("browser.urlbar.oneOffSearches", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #No thumbs search engine
#echo 'user_pref("browser.search.suggest.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #Startpage
echo 'user_pref("signon.autofillForms", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #No thumbs search engine
echo 'user_pref("signon.autofillForms.http ", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #No thumbs search engine
echo 'user_pref("signon.formlessCapture.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #No thumbs search engine
echo 'user_pref("signon.storeWhenAutocompleteOff", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #No thumbs search engine
echo 'user_pref("browser.formfill.enable", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #No thumbs search engine
echo 'user_pref("extensions.formautofill.addresses.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #No thumbs search engine
echo 'user_pref("extensions.formautofill.available", off);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #No thumbs search engine
echo 'user_pref("extensions.formautofill.creditCards.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #No thumbs search engine
echo 'user_pref("extensions.formautofill.heuristics.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #No thumbs search engine
echo 'user_pref("extensions.formautofill.section.enabled", false);' | tee -a ~/.mozilla/firefox/*.default/prefs.js #No thumbs search engine

### END FIREFOX PREFERENCES ###

#Icecat
aurman -S icecat-bin --noconfirm --needed

#Opera
sudo pacman -S opera opera-developer --noconfirm --needed

#Vivaldi
sudo pacman -S vivaldi --noconfirm --needed

#Chromium
sudo pacman -S chromium --noconfirm --needed
#vim -c ":%s,google.com,ixquick.com,g" -c ":wq" ~/.config/chromium/Default/Preferences
#vim -c ":%s,Google,Ixquick,g" -c ":wq" ~/.config/chromium/Default/Preferences
#vim -c ":%s,yahoo.com,google.jp/search?q=%s&pws=0&ei=#cns=0&gws_rd=ssl,g" -c ":wq" ~/.config/chromium/Default/Preferences
#vim -c ":%s,Yahoo,Google,g" -c ":wq" ~/.config/chromium/Default/Preferences
#CREATEHASH=$(sha256sum ~/.config/chromium/Default/Preferences)
#HASH=$(echo $CREATEHASH | head -n1 | sed -e 's/\s.*$//')
#HASHPREF=$(echo $HASH | awk '{print toupper($0)}')
#vim -c ":%s/"super_mac":".*"}}/"super_mac":"$HASHPREF"}}/g' -c ":wq" ~/.config/chromium/Default/'Secure Preferences'
chromium https://chrome.google.com/webstore/detail/cvim/ihlenndgcmojhcghmfjfneahoeklbjjh
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
chromium https://chrome.google.com/webstore/detail/video-downloadhelper/lmjnegcaeklhafolokijcfjliaokphfk
chromium https://chrome.google.com/webstore/detail/editthiscookie/fngmhnnpilhplaeedifhccceomclgfbg
chromium https://blockchain-dns.info/files/BDNS-1.0.8.crx
#$IRONFOLDER/./chrome https://chrome.google.com/webstore/detail/cvim/ihlenndgcmojhcghmfjfneahoeklbjjh
#$IRONFOLDER/./chrome https://chrome.google.com/webstore/detail/lovely-forks/ialbpcipalajnakfondkflpkagbkdoib
#$IRONFOLDER/./chrome https://chrome.google.com/webstore/detail/octotree/bkhaagjahfmjljalopjnoealnfndnagc
#$IRONFOLDER/./chrome https://chrome.google.com/webstore/detail/octolinker/jlmafbaeoofdegohdhinkhilhclaklkp
#$IRONFOLDER/./chrome https://chrome.google.com/webstore/detail/gitsense/fgnjcebdincofoebkahonlphjoiinglo
#$IRONFOLDER/./chrome https://chrome.google.com/webstore/detail/where-is-it/cdgnplmebagbialenimejpokfcodlkdm
#$IRONFOLDER/./chrome https://chrome.google.com/webstore/detail/octoedit/ecnglinljpjkbgmdpeiglonddahpbkeb
#$IRONFOLDER/./chrome https://chrome.google.com/webstore/detail/octo-preview/elomekmlfonmdhmpmdfldcjgdoacjcba
#$IRONFOLDER/./chrome https://chrome.google.com/webstore/detail/octo-mate/baggcehellihkglakjnmnhpnjmkbmpkf
#$IRONFOLDER/./chrome https://chrome.google.com/webstore/detail/codeflower/mnlengnbfpfgcfdgfpkjekoaeophmmeh
#$IRONFOLDER/./chrome https://chrome.google.com/webstore/detail/github-show-email/pndebicblkfcinlcedagfhjfkkkecibn
#$IRONFOLDER/./chrome  https://chrome.google.com/webstore/detail/restlet-client-rest-api-t/aejoelaoggembcahagimdiliamlcdmfm?hl=pt-PT

#Icecat
sudo aurman -S icecat-bin --noconfirm --needed

#Elinks terminal browser
sudo pacman -S elinks --noconfirm --needed

#Tor-browser
LANGUAGE=$(locale | grep LANG | cut -d'=' -f 2 | cut -d'_' -f 1)
aurman -S "tor-browser-$LANGUAGE" --needed --noconfirm --noedit

### Python ###
sudo pacman -S python python3 --noconfirm --needed
sudo pacman -S python-pip python2-pip --noconfirm --needed
sudo pacman -S python-pylint python2-pylint --noconfirm --needed

#Some Python tools
sudo -H pip install percol #logs indexer
sudo -H pip install shyaml csvkit #yaml csv

#Spyder/iPython/Jupyter
sudo pacman -S spyder spyder3 --noconfirm --needed && sudo -H pip install psutil python-dateutil pygments #includes ipython with magics (http://ipython.readthedocs.io/en/stable/interactive/magics.html) and jupyter with qtconsole
sudo -H pip3 install matplotlib numpy numba Cython #extras
ipython profile create #default profile creation
IPYTHONPD=/home/$USER/.ipython/profile_default
cp -R $IPYTHONPD ${IPYTHONPD::-7}original
PYTHONSTARTUP=$IPYTHONPD/pythonstartup #startup imports
touch $PYTHONSTARTUP
printf "import matplotlib.pyplot as plt \n
import numpy as np" | tee -a $PYTHONSTARTUP
IPYTHONPDCONF=$IPYTHONPD/ipython_config.py #configuration
vim -c ":%s,#c.InteractiveShellApp.exec_files = \[\],c.InteractiveShellApp.exec_files = \['$PYTHONSTARTUP'\]" -c ":wq" $IPYTHONPDCONF
vim -c ":%s,#c.InteractiveShell.banner2 = '',c.InteractiveShell.banner2 = 'Ƀe ℋuman\, be κinđ\, be ωise  --  List of built-in objects-functions: https://docs.python.org/3/library/functions.html  --  List of attributes (methods): dir(function)  --  Full Python index https://docs.python.org/3/genindex-all.html  --  List profiles: /home/\$USER/.ipython/profile_\*  --  Default profile load file: $PYTHONSTARTUP  --  Default profile conf file: ls $IPYTHONPDCONF  --  IPython kernel conf file: http://ipython.readthedocs.io/en/stable/config/options/kernel.html  --  Extensions index: https://github.com/ipython/ipython/wiki/Extensions-Index  --  Check magics with %quickref and new ones with @register_nameofmagic or with class using @magics_class class MyMagics(Magics):        @nameofmagic  --  Shortcuts: http://ipython.readthedocs.io/en/stable/config/shortcuts/index.html',g" -c ":wq" $IPYTHONPDCONF
vim -c ":%s/#c.InteractiveShellApp.extensions = \[\]/c.InteractiveShellApp.extensions = \['autoreload', 'Cython'\]/g" -c ":wq" $IPYTHONPDCONF
vim -c ":%s/#c.InteractiveShell.colors = 'Neutral'/c.InteractiveShell.colors = 'Linux'/g" -c ":wq" $IPYTHONPDCONF
vim -c ":%s/#c.TerminalInteractiveShell.editing_mode = 'emacs'/c.TerminalInteractiveShell.editing_mode = 'vi'/g" -c ":wq" $IPYTHONPDCONF
vim -c ":%s/#c.Completer.debug = False/c.Completer.debug = True/g" -c ":wq" $IPYTHONPDCONF
vim -c ":%s/#c.Completer.use_jedi = False/c.Completer.use_jedi = True/g" -c ":wq" $IPYTHONPDCONF
vim -c ":%s/#c.StoreMagics.autorestore = False/c.StoreMagics.autorestore = True/g" -c ":wq" $IPYTHONPDCONF
#vim -c ":%s/#c.InteractiveShell.pdb = False/c.InteractiveShell.pdb = True/g" -c ":wq" $IPYTHONPDCONF

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
gpg2 --keyserver pgp.mit.edu --recv-key B92A5F04EC949121
aurman -S beebeep --noconfirm --needed
gpg2 --delete-secret-and-public-keys --batch --yes B92A5F04EC949121

#Videocalls
sudo pacman -S libringclient ring-daemon ring-gnome --noconfirm --needed

#Messaging
sudo pacman -S keybase keybase-gui --noconfirm --needed
rm ~/.config/autostart/keybase_autostart.desktop #no autostart
#aurman -S jitsi --noconfirm --needed
#aurman -S qtox --noconfirm --needed
#aurman -S pybitmessage --noconfirm --needed

#All-in-a-box
aurman -S rambox-bin --noconfirm --needed

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
sudo vim -c ":%s.which ypcat.which ypcat 2>/dev/null.g" -c ":wq" /usr/share/tiger/systems/default/gen_passwd_sets #only for dns/ldap servers
sudo vim -c ":%s.which niscat.which niscat 2>/dev/null|g" -c ":wq" /usr/share/tiger/systems/default/gen_passwd_sets #only for dns/ldap servers
sudo tiger

#PKGs Audit
sudo pacman -S arch-audit --noconfirm --needed
sudo arch-audit

### Autoremove and Snapshot ###
sudo pacman -Rns "$(pacman -Qtdq)" --noconfirm
sudo pacman -Qq | sudo paccheck --sha256sum --quiet
#snapper -c initial create --description initial #Make snapshot initial (no chsnap for ext4)

### Extras ###
#Firmware
aurman -S epson-inkjet-printer-escpr --noconfirm --needed
#aurman -S wd719x-firmware aic94xx --noconfirm --needed

#Frugalware
#wget http://www13.frugalware.org/pub/frugalware/frugalware-stable-iso/fvbe-2.1-gnome-x86_64.iso

#Tails
#wget https://tails.braingap.uk/tails/stable/tails-amd64-3.6.2/tails-amd64-3.6.2.iso
#wget https://tails.boum.org/torrents/files/tails-amd64-3.6.2.iso.sig

echo "EOF"
