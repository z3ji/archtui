#!/bin/bash

# Function to check if the user has root privileges
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script requires root privileges to install packages. Please run it as root or using sudo."
        exit 1
    fi
}

# Function to install dialog if not already installed
install_dialog() {
    if ! command -v dialog &> /dev/null; then
        echo "Installing dialog..."
        pacman -S --noconfirm dialog
    fi
}

# Function to partition the disk
partition_disk() {
    # Create partitions
    parted -s /dev/sda mklabel gpt
    parted -s /dev/sda mkpart primary fat32 1MiB 512MiB
    parted -s /dev/sda set 1 boot on
    parted -s /dev/sda mkpart primary btrfs 512MiB 100%

    # Format partitions
    mkfs.ext4 /dev/sda1
    mkfs.btrfs /dev/sda2

    # Mount the Btrfs partition
    mount /dev/sda2 /mnt

    # Create Btrfs subvolumes
    btrfs subvolume create /mnt/@root
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@var

    # Mount subvolumes
    umount /mnt
    mount -o subvol=@root /dev/sda2 /mnt
    mkdir -p /mnt/{boot,home,var}
    mount /dev/sda1 /mnt/boot
    mount -o subvol=@home /dev/sda2 /mnt/home
    mount -o subvol=@var /dev/sda2 /mnt/var
}

# Function to install the base Arch Linux system
install_base_system() {
    # Generate an fstab file
    genfstab -U /mnt >> /mnt/etc/fstab

    # Change root to the new system
    arch-chroot /mnt /bin/bash <<EOF
    # Install base system packages
    pacman -S --noconfirm base base-devel linux linux-firmware btrfs-progs grub efibootmgr

    # Install network tools (optional)
    pacman -S --noconfirm networkmanager

    # Configure and install GRUB
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

    # Enable essential services (optional)
    systemctl enable NetworkManager
EOF
}

# Function to configure the system
configure_system() {
    # Set hostname
    hostname=$(dialog --backtitle "ArchTUI" --inputbox "Enter hostname:" 8 60 2>&1 >/dev/tty)
    echo "$hostname" > /etc/hostname

    # Set up network (optional)
    # Configure network settings here...

    # Set root password
    dialog --backtitle "ArchTUI" --title "Root Password" --insecure --passwordbox "Enter root password:" 10 60 2>&1 >/dev/tty | passwd --stdin root

    # Add a new user
    username=$(dialog --backtitle "ArchTUI" --inputbox "Enter username:" 8 60 2>&1 >/dev/tty)
    useradd -m "$username"
    dialog --backtitle "ArchTUI" --title "User Password" --insecure --passwordbox "Enter password for $username:" 10 60 2>&1 >/dev/tty | passwd --stdin "$username"

    # Add the user to sudoers (optional)
    usermod -aG wheel "$username"
}

# Function to add additional pacman packages
add_additional_packages() {
    dialog --backtitle "ArchTUI" --title "Additional Packages" --inputbox "Enter additional pacman packages (space-separated):" 10 60 2>&1 >/dev/tty | xargs pacman -S --noconfirm
}

# Main function to display the menu and handle user choices
main() {
    check_root_privileges
    install_dialog

    # Define menu options as an associative array with descriptions
    declare -A menu_options=(
        [1]="Partition Disk: Partition the disk to prepare for installation"
        [2]="Install Base System: Install the base Arch Linux system"
        [3]="Configure System: Configure system settings and user accounts"
        [4]="Add Additional Pacman Packages: Add additional packages using pacman"
        [5]="Exit: Exit the installer"
    )

    # Create an array to hold dialog menu options
    dialog_options=()
    # Sort the keys in ascending order
    sorted_keys=($(echo "${!menu_options[@]}" | tr ' ' '\n' | sort -n))
    for key in "${sorted_keys[@]}"; do
        dialog_options+=("$key" "${menu_options[$key]}")
    done

    while true; do
        # Display the menu
        choice=$(dialog --backtitle "ArchTUI" --title "Main Menu" --menu "Choose an option:" 15 60 5 "${dialog_options[@]}" 2>&1 >/dev/tty)

        # Handle user choice
        case $choice in
            1)
                # Partition Disk
                partition_disk
                ;;
            2)
                # Install Base System
                install_base_system
                ;;
            3)
                # Configure System
                configure_system
                ;;
            4)
                # Add Additional Pacman Packages
                add_additional_packages
                ;;
            5)
                # Exit
                dialog --msgbox "Exiting..." 10 40
                exit
                ;;
            *)
                # If the user cancels or presses Escape, exit the installer
                dialog --msgbox "Exiting..." 10 40
                exit
                ;;
        esac
    done
}

# Start the installer
main