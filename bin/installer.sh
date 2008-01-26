#!/bin/sh

. /conf/tcos.conf
. /scripts/functions
. /conf/tcos-run-functions

# size of vfat partition
hda1_size=100


FDISK=/sbin/fdisk
INSTALL_MBR=/sbin/install-mbr

# translatable strings
MSG_TITLE="TCOS hdd installer"
MSG_WELCOME="Welcome to TCOS hdd installer.\nDo you want to install TCOS in thin client hdd?"
MSG_CANCEL="Cancelled, exiting now..."
MSG_NOHDD="Not hard disk detected. Check if TCOS_DISABLE_IDE is set in tcos.conf."
MSG_HDD_DETECTED="Detected partitions:\n\n"
MSG_DELETE_ALL_DISK="Do you want to delete entire first hard disk?\n\nThis installer will create 2 parts:\n* /dev/hda1 vfat with kernel\n* /dev/hda2 swap (hdd memory)\nRECOMENDED: yes"
MSG_NOPARTIIONS="No partitions detected, please rerun installer.sh and select all disk."

EXIT () {
 # fixme clean umount and do some things here
 exit $1
}


MSG () {
whiptail --title "$MSG_TITLE" "$@" 12 80
}

LIST () {
whiptail --title "$MSG_TITLE" "$@" 20 80
}


umount_all () {
  log_begin_msg "Umounting all parts in  /dev/hda"
    data=$(grep ^/dev/hda /proc/mounts | awk '{print $1}')
    for part in $data; do
      umount -l $part > /dev/null 2>&1
    done
    swaps=$(grep ^/dev/hda /proc/swaps | awk '{print $1}')
    for part in $swaps; do
      swapoff $part > /dev/null 2>&1
    done
  log_end_msg
}

mount_swap () {
  log_begin_msg "Mount swap /dev/hda2"
    swapon /dev/hda2 > /dev/null 2>&1
  log_end_msg
}


make_all_parts () {

  umount_all

  # hda hdd size (in MB)
  hda_size=$(LANG=C $FDISK -l|grep ^Disk|head -1 | awk '{print $5/1000000}')

  # swap (in MB) = Total_RAM (kB) * 2 / 1000
  swap_size=$(awk '/MemTotal/ {print int($2*2/1000)}' /proc/meminfo)

  # ext3=rest
  #hda1_size=$(echo "$hda_size $swap_size" | awk '{print int($1-$2)}')


  # clean MBR
  log_begin_msg "Cleaning MBR of /dev/hda"
    dd if=/dev/zero of=/dev/hda bsize=512 count=1 >/dev/null 2>&1
    $INSTALL_MBR --force /dev/hda
  log_end_msg

  log_begin_msg "Making 2 partitions in /dev/hda"
    #echo -n "   hda1=${hda1_size}M hda2=${swap_size}M ...(please wait)"
    # call fdisk
$FDISK /dev/hda << EOF 2>/dev/null >/dev/null
o
n
p
1
1
+${hda1_size}M
n
p
2

+${swap_size}M
t
1
b
t
2
82
a
1
w
EOF
  log_end_msg " done"

  # format parts
  log_begin_msg "Format hda1 as vfat (${hda1_size}M)"
    mkfs.vfat /dev/hda1 >/dev/null 2>&1
  log_end_msg

  log_begin_msg "Format hda2 as swap (${swap_size}M)"
    mkswap /dev/hda2 >/dev/null 2>&1
  log_end_msg

  mount_swap

}


install_kernel () {
  # mount hda1
  mkdir -p /target
  mount -tvfat /dev/hda1 /target > /dev/null 2>&1

  if [ $(grep -c /dev/hda1 /proc/mounts) -lt 1 ]; then
     echo ""
     echo "    ERROR: Can't mount /dev/hda1 in /target"
     echo ""
     exit 1
  fi

  NET_INSTALL=1
  # check if we are booting from cdrom
  if [ $(grep -c initrd.cdrom /proc/cmdline ) -gt 0 ]; then

    # instalation from cdrom
    cdroms=$(awk '/iso9660/ {print $1}' /etc/fstab)
    mkdir /cdrom
    for cdrom in $cdroms; do
       mount $cdrom /cdrom &>/dev/null
       echo "Waiting for cdrom ${cdrom}..."
       sleep 5
       if [ $(grep -c "/cdrom" /proc/mounts) -gt 0 ]; then
         if [ ! -d /cdrom/boot/grub ] && [ ! -d /cdrom/isolinux ]; then
           echo "ERROR: $cdrom don't have grub or isolinux"
         else
           NET_INSTALL=0
           #echo "$cdrom have grub or isolinux"
           break
         fi
       fi
    done

    if [ -d /cdrom/boot/grub ]; then
    log_begin_msg "Copying grub files to /dev/hda1"
      cp /cdrom/boot/vmlinuz      /target/vmlinuz
      cp /cdrom/boot/initrd.cdrom /target/initrd.gz
    log_end_msg
    elif [ -d /cdrom/isolinux ]; then
    log_begin_msg "Copying isolinux files to /dev/hda1"
      cp /cdrom/isolinux/vmlinuz       /target/vmlinuz
      cp /cdrom/isolinux/initrd.cdrom  /target/initrd.gz
      cp /cdrom/isolinux/tcos.msg      /target/tcos.msg
      cp /cdrom/isolinux/help.msg      /target/help.msg
      cp /cdrom/isolinux/help2.msg     /target/help2.msg
      cp /cdrom/isolinux/logo.lss      /target/logo.lss
    log_end_msg
THEME="
DISPLAY tcos.msg
F0 tcos.msg
F1 help.msg
F2 help2.msg
"
    else
      echo "Not medium found, using network install"
      NET_INSTALL=1
    fi
  fi

   if [ $NET_INSTALL = 1 ]; then
    log_begin_msg "Downloading kernel"
      download_file /tcos/vmlinuz-$(uname -r)  /target/vmlinuz > /dev/null
    log_end_msg

    log_begin_msg "Downloading initramfs"
      download_file /tcos/initramfs-$(uname -r) /target/initrd.gz > /dev/null
      download_file /tcos/initramfs-$(uname -r)-nfs /target/initrd.nfs > /dev/null
    log_end_msg

    log_begin_msg "Downloading usr.squashfs"
      download_file /tcos/usr-$(uname -r).squashfs /target/usr.squashfs > /dev/null
    log_end_msg

    log_begin_msg "Downloading startup logos and help"
      download_file /tcos/tcos.msg /target/tcos.msg
      download_file /tcos/help.msg /target/help.msg
      download_file /tcos/help2.msg /target/help2.msg
      download_file /tcos/logo.lss /target/logo.lss
THEME="
DISPLAY tcos.msg
F0 tcos.msg
F1 help.msg
F2 help2.msg
"
    log_end_msg
   fi


  # check for min ram
  memory=$(awk '/^MemTotal/ {print int($2/1000)}' /proc/meminfo)
  if [ $memory -lt $TCOS_MIN_RAM ]; then
    log_begin_msg "Using NFS boot images ($TCOS_MIN_RAM Mb RAM)"
      DEFAULT="nfs"
    log_end_msg
  else
    log_begin_msg "Using TFTP boot images"
      DEFAULT="tcos"
    log_end_msg
  fi

  log_begin_msg "Installing syslinux"
    [ -f /usr/lib/syslinux/mbr.bin ] && cat /usr/lib/syslinux/mbr.bin  > /dev/hda
    syslinux /dev/hda1

cat << EOF > /target/syslinux.cfg
DEFAULT $DEFAULT
TIMEOUT 50
$THEME
PROMPT 1
LABEL tcos
        KERNEL vmlinuz
        APPEND ramdisk_size=65536 initrd=initrd.gz root=/dev/ram0 BOOT=tcos ${TCOS_INSTALLER_BOOT_OPT}

LABEL update
        KERNEL vmlinuz
        APPEND ramdisk_size=65536 initrd=initrd.gz root=/dev/ram0 BOOT=tcos ${TCOS_INSTALLER_BOOT_OPT} startx=N installer-update

LABEL nfs
        KERNEL vmlinuz
        APPEND ramdisk_size=32768 initrd=initrd.nfs root=/dev/ram0 BOOT=tcos ${TCOS_INSTALLER_BOOT_OPT}

LABEL nfsupdate
        KERNEL vmlinuz
        APPEND ramdisk_size=32768 initrd=initrd.nfs root=/dev/ram0 BOOT=tcos ${TCOS_INSTALLER_BOOT_OPT} startx=N installer-update

# syslinux.cfg generated by tcos installer on $(date)

EOF
  log_end_msg

  # umount vfat partition
  sync
  umount /dev/hda1
}


format_part () {
  #$1 is partition
  mkfs.ext3 "$1"
}


# update local files if "--update" is passed
if [ "$1" = "--update" ]; then
    log_begin_msg "Updating installed system"
    log_end_msg

    install_kernel
    exit 0
fi

# install without questions if "--oeminstall" is passed
if [ "$1" = "--oeminstall" ]; then
    log_begin_msg "Unattended INSTALL"
    log_end_msg

    make_all_parts
    install_kernel
    exit 0
fi


# welcome message
MSG --defaultno --yesno "$MSG_WELCOME" 10 80
if [ $? != 0 ]; then
  MSG --msgbox "$MSG_CANCELLED"
  EXIT 1
fi

# ask for delete all disk
MSG --defaultno --yesno "$MSG_DELETE_ALL_DISK"
if [ $? != 0 ]; then
  TCOS_TYPE="one"
else
  TCOS_TYPE="entire"
fi




if [ "$TCOS_TYPE" = "one" ]; then

   MSG --defaultno --yesno "This part isn't done yet, exit now..."
   exit 1

   parts=$(cat /proc/partitions | awk '{print $4}'| grep "^[hs]d[a-z][0-9]")
   num_parts=$(cat /proc/partitions | awk '{print $4}'| grep -c "^[hs]d[a-z][0-9]")

   if [ "$num_parts" = "0" ]; then
      MSG --msgbox "$MSG_NOPARTIIONS"
      EXIT 1
   fi

   # show partitions
   parts_types=$($FDISK -l |grep ^/dev | awk '{ if ($2 == "*") {print $1":"$7}; if ($2 != "*") {print $1":"$6" "$7}; }')
   LIST --msgbox "$MSG_HDD_DETECTED${parts_types}"

   parts=""
   for part in $parts_types; do
     device=$(echo $part | awk -F ":" '{print $1}' | awk -F "/" '{print $3}')
     type=$(echo $part | awk -F ":" '{print $2}')
     parts="$parts $device $type"
   done
   #echo $parts
   whiptail --title "$TITLE" --menu "Select part:" 20 80 5 $parts 2> /tmp/tcos_selected_part
   selected_part=$(cat /tmp/tcos_selected_part) && rm /tmp/tcos_selected_part

    # ask for format
    MSG --defaultno --yesno "Do you want to format $selected_part?"
    if [ $? != 0 ]; then
        MSG --msgbox "$MSG_CANCELLED"
    EXIT 1
    else
        format_part /dev/$selected_part
    fi

else

 make_all_parts
 install_kernel
 
fi


