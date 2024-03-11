#!/bin/sh

# Archlinux Install script by Trinteen 2023

############################
# VARIABLES                #
############################

#=> Defines system drive:
export V_SYS_HD="/dev/sda"

#=> Defines partitions:
export V_BOOT_SIZE="200"
export V_SWAP_SIZE="8000"

#=> Defines county:
export V_COUNTRY="CZ"

#=> Defines timezone:
export V_TIMEZONE="Europe/Prague"

#=> Defines language system:
export V_LANGUAGE="cs_CZ"

#=> Defines keyboard layout:
export V_KEYMAP="cz"

#=> Defines hostname:
export V_HOSTNAME="archlinux"

#=> Defines ROOT password:
export V_ROOT_PWD="root"

#=> Defines user accont:
export V_USER_NAME="user"
export V_USER_PASS="user"

#=> Defines GUI desktop:
export V_GUI="sddm plasma kde-applications"

#=> Defines extra packages:
export V_EXTRA_PKG="zip unzip unrar"

#=> Defines AUR packages (NOT WORKING NOW):
export V_AUR_PKG=()

#=> Defines CPU microcode:
export V_CPU_UCODE="intel-ucode"

#=> Defines GPU driver:
export V_GPU="mesa"

#=> Enable my services:
export V_SERVICES=("sddm.service")

############################
# SCRIPT                   #
############################

#=> TimeDateCtl NTP:
echo "=> 1. NTP = Enabled"
timedatectl set-ntp true 1> /dev/null

#=> Keyboard layout:
echo "=> 2. KEYMAP = ${V_KEYMAP}"
loadkeys ${V_KEYMAP} 1> /dev/null

#=> Initialization:
echo "=> 3. SETUP PARTITIONS = ${V_SYS_HD}"

    #=> Help math partition:
    P_B_S=1
    P_B_E=$(($P_B_S+$V_BOOT_SIZE))
    P_S_S=$(($P_B_E))
    P_S_E=$(($P_S_S+$V_SWAP_SIZE))
    P_R_S=$(($P_S_E))

    #=> Clearing system drive:
    echo ":: Clearing system drive.."
    parted -s ${V_SYS_HD} mklabel GPT &> /dev/null

    #=> Create EFI partition:
    echo ":: Create EFI partition"
    parted -s ${V_SYS_HD} mkpart primary fat32 ${P_B_S} ${P_B_E} 1> /dev/null
    parted -s ${V_SYS_HD} set 1 boot on 1> /dev/null

    #=> Create SWAP partition:
    echo ":: Create SWAP partition"
    parted -s ${V_SYS_HD} mkpart primary linux-swap ${P_S_S} ${P_S_E} 1> /dev/null

    #=> Create ROOT partition:
    echo ":: Create ROOT partition"
    parted -s -- ${V_SYS_HD} mkpart primary ${V_ROOT_FS} ${P_R_S} -0 1> /dev/null

    #=> Format partitions:
    echo ":: Format EFI partition"
    mkfs.fat -F 32 -L ARCH_EFI ${V_SYS_HD}1 1> /dev/null
    echo ":: Format ROOT partition"
    mkfs.btrfs -L ARCH_ROOT ${V_SYS_HD}3 1> /dev/null

    #=> Activation SWAP:
    echo ":: Activation SWAP partition"
    mkswap ${V_SYS_HD}2
    swapon ${V_SYS_HD}2

#=> Mounting partitions:
echo "=> 4. MOUNTING PARTITIONS = ${V_SYS_HD}"

    #=> Mount ROOT partition:
    echo ":: Mount ROOT partition to /mnt"
    mount ${V_SYS_HD}3 /mnt

    #=> Btrfs:
    btrfs sub create /mnt/@
    btrfs sub create /mnt/@home
    umount /mnt
    mount -o noatime,nodiratime,compress=zstd,space_cache=v2,ssd,subvol=@ ${V_SYS_HD}3 /mnt
    mount -o noatime,nodiratime,compress=zstd,space_cache=v2,ssd,subvol=@home ${V_SYS_HD}3 /mnt/home

    #=> Mount BOOT partition:
    echo ":: Mount BOOT partition to /mnt/boot"
    mkdir -p /mnt/boot
    mount ${V_SYS_HD}1 /mnt/boot

#=> Install system:
echo "=> 5. INSTALATION NEW SYSTEM TO ${V_SYS_HD}"

    #=> Pacman setting before install:
    echo ":: Update mirrorlist for country: ${V_COUNTRY}"
    pacman --noconfirm --needed -Sy pacman-contrib
    curl -s "https://archlinux.org/mirrorlist/?country=${V_COUNTRY}&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors - > /etc/pacman.d/mirrorlist

    #=> Run pacstrap:
    echo ":: Downloading packages for NEW SYSTEM"
    pacstrap /mnt base btrfs-progs wget base-devel cups linux linux-firmware nano git mc avahi samba smbclient gvfs gvfs-smb xorg fish networkmanager network-manager-applet efibootmgr wireless_tools wpa_supplicant os-prober mtools ${V_GPU} ${V_CPU_UCODE} ${V_GUI}

    #=> Generate new FSTAB:
    echo ":: Generate new FSTAB file"
    genfstab -p -U /mnt >> /mnt/etc/fstab 1> /dev/null

#=> Post settings in chroot:
echo "=> 6. Post-install chroot settings"

    #=> Set localtime:
    echo ":: Set localtime = ${V_TIMEZONE}"
    arch-chroot /mnt bash -c "ln -sf /usr/share/zoneinfo/${V_TIMEZONE} /etc/localtime && hwclock --systohc" 1> /dev/null

    #=> Set language:
    echo ":: Set language = ${V_LANGUAGE}"
    arch-chroot /mnt bash -c "sed -i 's/#${V_LANGUAGE}.UTF-8 UTF-8/${V_LANGUAGE}.UTF-8 UTF-8/' /etc/locale.gen && locale-gen > /dev/null && echo 'LANG=${V_LANGUAGE}.UTF-8' > /etc/locale.conf && echo 'KEYMAP=${V_KEYMAP}' > /etc/vconsole.conf" 1> /dev/null

    #=> Set hostname:
    echo ":: Set hostname = ${V_HOSTNAME}"
    arch-chroot /mnt bash -c "echo '${V_HOSTNAME}' > /etc/hostname && echo -e '\n127.0.0.1       localhost\n::1             localhost\n127.0.1.1       ${V_HOSTNAME}.localdomain ${V_HOSTNAME}' >> /etc/hosts" 1> /dev/null

    #=> Set new ROOT password:
    echo ":: Set ROOT password = ${V_ROOT_PWD}"
    arch-chroot /mnt bash -c "echo 'root:'${V_ROOT_PWD}'' | chpasswd" 1> /dev/null

    #=> Create user:
    echo ":: Create new user = ${V_USER_NAME}:${V_USER_PASS}"
    arch-chroot /mnt bash -c "useradd -m ${V_USER_NAME} && echo "${V_USER_NAME}:${V_USER_PASS}" | chpasswd && usermod -aG wheel,audio,video,optical,storage,games -s /usr/bin/fish ${V_USER_NAME}" 1> /dev/null

    #=> Install sudo & setup:
    echo ":: Install SUDO and configure"
    arch-chroot /mnt bash -c "pacman -S --noconfirm sudo > /dev/null && echo -e '%wheel ALL=(ALL) ALL\nDefaults rootpw' > /etc/sudoers.d/99_wheel" 1> /dev/null

    #=> Configuration X11:
    echo ":: Configuration X11"
    arch-chroot /mnt bash -c "echo -e 'Section \"InputClass\" \n Identifier \"system-keyboard\" \n MatchIsKeyboard \"on\" \n Option \"XkbLayout\" \"'${V_KEYMAP}'\" \n EndSection' > /etc/X11/xorg.conf.d/00-keyboard.conf" 1> /dev/null

    #=> Set DHCP network:
    echo ":: Set DHCP for network"
    arch-chroot /mnt bash -c "sed 's/^# interface=/interface=eth0/' /etc/rc.conf > /etc/rc.conf" 1> /dev/null

    #=> Setup initial ramdisk environment
    echo ":: Setup initial ramdisk environment"
    arch-chroot /mnt bash -c "sed -i 's/filesystems fsck/btrfs filesystems/g' /etc/mkinitcpio.conf" 1> /dev/null
    arch-chroot /mnt bash -c "mkinitcpio -p linux" 1> /dev/null

    #=> Setup SystemD-Boot:
    echo ":: Configuration Systemd-boot"
    arch-chroot /mnt bash -c "bootctl --path=/boot install" 1> /dev/null
    arch-chroot /mnt bash -c "echo -e 'title Arch Linux' >> /boot/loader/entries/arch.conf" 1> /dev/null
    arch-chroot /mnt bash -c "echo -e 'linux /vmlinuz-linux' >> /boot/loader/entries/arch.conf" 1> /dev/null
    arch-chroot /mnt bash -c "echo -e 'initrd  /initramfs-linux.img' >> /boot/loader/entries/arch.conf" 1> /dev/null´
    UUID_DISK=$(blkid -s UUID -o value ${V_SYS_HD}3)
    arch-chroot /mnt bash -c "echo -e 'options root=UUID=${UUID_DISK} rootflags=subvol=@ rw' >> /boot/loader/entries/arch.conf" 1> /dev/null

    #=> Makepkg
    echo ":: Edit MAKEPKG"
    arch-chroot /mnt bash -c "sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(nproc)"/g' /etc/makepkg.conf" 1> /dev/null
    arch-chroot /mnt bash -c "sed -i 's#-march=x86-64 -mtune=generic#-march='$(gcc -Q -march=native --help=target | grep march | awk '{print $2}' | head -1)'#g' /etc/makepkg.conf" 1> /dev/null

    #=> Enabled multilib:
    if [ "$(uname -m)" = "x86_64" ];then
        echo ":: Enable MULTILIB repo in PACMAN"
        arch-chroot /mnt bash -c "echo -e '[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf" 1> /dev/null
    fi

    #=> Enable Chaotic-aur
    echo ":: Enable chaotic-aur repo"
    arch-chroot /mnt bash -c "pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com" 1> /dev/null
    arch-chroot /mnt bash -c "pacman-key --lsign-key 3056513887B78AEB" 1> /dev/null
    arch-chroot /mnt bash -c "pacman --noconfirm -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'" 1> /dev/null
    arch-chroot /mnt bash -c "echo -e '[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' >> /etc/pacman.conf" 1> /dev/null    

    #=> Paru AUR Helper
    echo ":: Install extra packages"
    arch-chroot /mnt bash -c "pacman --noconfirm --needed -Sy paru" 1> /dev/null

    #=> Pacman config edit:
    echo ":: Pacman config edit"
    arch-chroot /mnt bash -c "sed -i 's/^#ParallelDownloads/ParallelDownloads/g' /etc/pacman.conf" 1> /dev/null
    arch-chroot /mnt bash -c "sed -i 's/^#Color/Color/g' /etc/pacman.conf" 1> /dev/null
    arch-chroot /mnt bash -c "sed -i 's/VerbosePkgLists/VerbosePkgLists\nILoveCandy/g' /etc/pacman.conf" 1> /dev/null
    arch-chroot /mnt bash -c "sed -i 's/^#VerbosePkgLists/VerbosePkgLists\n/g' /etc/pacman.conf" 1> /dev/null

    #=> Extra packages:
    echo ":: Install extra packages"
    arch-chroot /mnt bash -c "pacman --noconfirm --needed -Sy ${V_EXTRA_PKG}" 1> /dev/null

    #=> Install AUR packages:
    echo ":: Install AUR packages"
    for aur in ${V_AUR_PKG[@]}; do
        echo "This function not working now!"
        echo ${aur}
    done

    #=> Enable my services:
    echo ":: Enable services"
    for enable_services in ${V_SERVICES[@]}; do
        echo $enable_services
        arch-chroot /mnt bash -c "systemctl enable ${enable_services}" 1> /dev/null
    done

    #=> Enable services:
    arch-chroot /mnt bash -c "systemctl enable NetworkManager.service" 1> /dev/null
    arch-chroot /mnt bash -c "systemctl enable cups.service" 1> /dev/null
    arch-chroot /mnt bash -c "systemctl enable avahi-daemon.service" 1> /dev/null
    arch-chroot /mnt bash -c "systemctl enable smb.service" 1> /dev/null
    
    #=> Exit chroot:
    arch-chroot /mnt bash -c "exit"

#=> Umount disk & reboot system:
echo "=> 7. Umount ${V_SYS_HD} & reboot system..."
    
    #=> umount disk:
    umount -l /mnt 1> /dev/null

    #=> reboot system:
    sleep 10 && reboot
