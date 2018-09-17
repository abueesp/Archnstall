changemymac(){
ifconfig -a | grep -B 3 ether
read -p "Those are your macs. Choose the ethernet interface (eth, wlan...) you want to change. It will be sustitued by a random MAC, so write before in case it could have been mac filtering whitelisted : " wlan
RANGE=255
#set integer ceiling
number=$RANDOM
numbera=$RANDOM
numberb=$RANDOM
numberc=$RANDOM
numberd=$RANDOM
numbere=$RANDOM
#generate random numbers
let "number %= $RANGE"
let "numbera %= $RANGE"
let "numberb %= $RANGE"
let "numberc %= $RANGE"
let "numberd %= $RANGE"
let "numbere %= $RANGE"
#ensure they are less than ceiling
#octets='64:60:2F' if you want to set a triple fix set of octets then #comment 3 octets
#set mac stem
octet=$(echo "obase=16;$number" | bc)
octeta=$(echo "obase=16;$numbera" | bc)
octetb=$(echo "obase=16;$numberb" | bc)
octetc=$(echo "obase=16;$numberc" | bc)
octetd=$(echo "obase=16;$numberd" | bc)
octete=$(echo "obase=16;$numbere" | bc)
macadd="${octet}:${octeta}:${octetb}:${octetc}:${octetd}:${octete}"
echo "Preliminar MAC"
echo $macadd
#use a command line tool to change int to hex(bc is pretty standard) they are not really octets.  just sections.
firstdigit=${octet:0:1}
while :; do
	if [ $((firstdigit%2)) -eq 0 ];
		then echo "$firstdigit is valid" && break
	else
		number=$RANDOM
		let "number %= $RANGE"
		octet=$(echo "obase=16;$number" | bc)
		firstdigit=${octet:0:1}
		echo "Validating MAC with $firstdigit"
	fi
done
#assure first digit is even
macadd="${octet}:${octeta}:${octetb}:${octetc}:${octetd}:${octete}"
echo "Final MAC"
echo $macadd
read -p "This would be your new MAC. Click enter to fix the change:"
#concatenate values and add dashes
macaddr=$(echo $macadd)
sudo ifconfig $wlan down
sudo ifconfig $wlan hw ether $macaddr
sudo ifconfig $wlan up
ifconfig -a | grep -b3 ether
cookie=$(mcookie)
echo "And, as a present, here you have a hash you can use as a cookie wherever: ($cookie). Enjoy!"
}
