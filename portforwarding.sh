#https://pastebin.com/aXZQVyiM
### Port knocking ###
#Daemon
sudo pacman -S knockd --noconfirm --needed

#Setting daemon
ping1=$(shuf -i 1000-10000 -n 1)
ping2=$(shuf -i 1000-10000 -n 1)
ping3=$(shuf -i 1000-10000 -n 1)
sudo rm /etc/knockd.conf.1
sudo cp /etc/knockd.conf /etc/knockd.conf.1
sudo ifconfig
read -p "Introduce host": HOST
printf "[options]
        logfile = /var/log/knockd.log
[opencloseSSH]
        sequence      = $ping1:tcp,$ping2:tcp,$ping3:tcp
        seq_timeout   = 10
        tcpflags      = syn,ack
        start_command = /usr/bin/iptables -A TCP -s \$HOST -p tcp --dport 22 -j ACCEPT
        cmd_timeout   = 50
        stop_command  = /usr/bin/iptables -D TCP -s \$HOST -p tcp --dport 22 -j ACCEPT" | sudo tee /etc/knockd.conf

#Client
printf '#Dynamic
HOST=$1
shift

for ARG in "$@"
do
        nmap -Pn --host_timeout 100 --max-retries 0 -p \$ARG \$HOST
done
#Stable
nmap -Pn --host_timeout 100 --max-retries 0 -p $ping1 $HOST
nmap -Pn --host_timeout 100 --max-retries 0 -p $ping2 $HOST
nmap -Pn --host_timeout 100 --max-retries 0 -p $ping3 $HOST' | tee knock.sh
sudo mv knock.sh /bin/knockknock

#Setting client
echo "sh <knockknock host $ping1 $ping2 $ping3>   # Now logins are allowed:  ssh user@host #Check last logins using cat /proc/net/xt_recent/SSH*" | tee -a knockknock
sudo cat /bin/knockknock | tee -a knockknock #the program
