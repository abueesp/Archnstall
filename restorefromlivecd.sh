sudo fdisk -l
read -p "Which is the Linux partition to mount (sda1,sda5...)? " TARGETSDA

TARGETDEV="/dev/$TARGETSDA"
TARGETDIR="/mnt/OS0/"

sudo mkdir -p $TARGETDIR

sudo mount $TARGETDEV $TARGETDIR
sudo mount -t proc /proc $TARGETDIR/proc
sudo mount --rbind /sys $TARGETDIR/sys
sudo mount --rbind /dev $TARGETDIR/dev

sudo cp /etc/hosts $TARGETDIR/etc
sudo cp /etc/resolv.conf $TARGETDIR/etc

sudo chroot $TARGETDIR rm /etc/mtab 2> /dev/null
sudo chroot $TARGETDIR ln -s /proc/mounts /etc/mtab
read -p "Now you are going to chroot. Remember to upgrade linux, dkms and linux-headers if you had a kernel panic, and apply mkinitcpio -p linux, it was a init related oops."
sudo chroot $TARGETDIR
#arch-chroot $TARGETDIR #more convenient when using arch on both sides
