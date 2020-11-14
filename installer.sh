#!/bin/bash

# Function to check if the user has root privileges
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        dialog --backtitle "Error" --msgbox "This script requires root privileges to install packages. Please run it as root or using sudo." 10 60
        exit 1
    fi
}

# Function to install dialog if not already installed
install_dialog() {
    if ! command -v dialog &> /dev/null; then
        echo "Installing dialog..."
        pacman -S --noconfirm dialog
        if [ $? -ne 0 ]; then
            dialog --backtitle "Error" --msgbox "Failed to install dialog. Please install it manually and rerun the script." 10 60
            exit 1
        fi
    fi
}

# Function to partition the disk
partition_disk() {
    # Create partitions
    parted -s /dev/sda mklabel gpt || { dialog --backtitle "Error" --msgbox "Failed to create GPT partition table." 10 60; return 1; }
    parted -s /dev/sda mkpart primary fat32 1MiB 512MiB || { dialog --backtitle "Error" --msgbox "Failed to create EFI partition." 10 60; return 1; }
    parted -s /dev/sda set 1 boot on || { dialog --backtitle "Error" --msgbox "Failed to set boot flag on EFI partition." 10 60; return 1; }
    parted -s /dev/sda mkpart primary btrfs 512MiB 100% || { dialog --backtitle "Error" --msgbox "Failed to create Btrfs partition." 10 60; return 1; }

    # Format partitions
    mkfs.ext4 /dev/sda1 || { dialog --backtitle "Error" --msgbox "Failed to format EFI partition." 10 60; return 1; }
    mkfs.btrfs /dev/sda2 || { dialog --backtitle "Error" --msgbox "Failed to format Btrfs partition." 10 60; return 1; }

    # Mount the Btrfs partition
    mount /dev/sda2 /mnt || { dialog --backtitle "Error" --msgbox "Failed to mount Btrfs partition." 10 60; return 1; }

    # Create Btrfs subvolumes
    btrfs subvolume create /mnt/@root || { dialog --backtitle "Error" --msgbox "Failed to create root subvolume." 10 60; return 1; }
    btrfs subvolume create /mnt/@home || { dialog --backtitle "Error" --msgbox "Failed to create home subvolume." 10 60; return 1; }
    btrfs subvolume create /mnt/@var || { dialog --backtitle "Error" --msgbox "Failed to create var subvolume." 10 60; return 1; }

    # Mount subvolumes
    umount /mnt || { dialog --backtitle "Error" --msgbox "Failed to unmount Btrfs partition." 10 60; return 1; }
    mount -o subvol=@root /dev/sda2 /mnt || { dialog --backtitle "Error" --msgbox "Failed to mount root subvolume." 10 60; return 1; }
    mkdir -p /mnt/{boot,home,var} || { dialog --backtitle "Error" --msgbox "Failed to create mount directories." 10 60; return 1; }
    mount /dev/sda1 /mnt/boot || { dialog --backtitle "Error" --msgbox "Failed to mount EFI partition." 10 60; return 1; }
    mount -o subvol=@home /dev/sda2 /mnt/home || { dialog --backtitle "Error" --msgbox "Failed to mount home subvolume." 10 60; return 1; }
    mount -o subvol=@var /dev/sda2 /mnt/var || { dialog --backtitle "Error" --msgbox "Failed to mount var subvolume." 10 60; return 1; }
}


# Function to install the base Arch Linux system
install_base_system() {
    # Generate an fstab file
    genfstab -U /mnt >> /mnt/etc/fstab || { dialog --backtitle "Error" --msgbox "Failed to generate fstab file." 10 60; return 1; }

    # Change root to the new system
    arch-chroot /mnt /bin/bash <<EOF
    # Install base system packages
    pacman -S --noconfirm base base-devel linux linux-firmware btrfs-progs grub efibootmgr || { dialog --backtitle "Error" --msgbox "Failed to install base system packages." 10 60; exit 1; }

    # Install network tools (optional)
    pacman -S --noconfirm networkmanager || { dialog --backtitle "Error" --msgbox "Failed to install network tools." 10 60; exit 1; }

    # Configure and install GRUB
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || { dialog --backtitle "Error" --msgbox "Failed to install GRUB." 10 60; exit 1; }
    grub-mkconfig -o /boot/grub/grub.cfg || { dialog --backtitle "Error" --msgbox "Failed to generate GRUB configuration." 10 60; exit 1; }

    # Enable essential services (optional)
    systemctl enable NetworkManager || { dialog --backtitle "Error" --msgbox "Failed to enable NetworkManager service." 10 60; exit 1; }
EOF

    # Check if chroot command succeeded
    if [ $? -ne 0 ]; then
        dialog --backtitle "Error" --msgbox "Failed to change root to the new system." 10 60
        return 1
    fi
}

# Function to configure the system
configure_system() {
    # Set hostname
    hostname=$(dialog --backtitle "ArchTUI" --inputbox "Enter hostname:" 8 60 2>&1 >/dev/tty)
    echo "$hostname" > /etc/hostname || { dialog --backtitle "Error" --msgbox "Failed to set hostname." 10 60; return 1; }

    # Set up network (optional)
    # Configure network settings here...

    # Set root password
    dialog --backtitle "ArchTUI" --title "Root Password" --insecure --passwordbox "Enter root password:" 10 60 2>&1 >/dev/tty | passwd --stdin root || { dialog --backtitle "Error" --msgbox "Failed to set root password." 10 60; return 1; }

    # Add a new user
    username=$(dialog --backtitle "ArchTUI" --inputbox "Enter username:" 8 60 2>&1 >/dev/tty)
    useradd -m "$username" || { dialog --backtitle "Error" --msgbox "Failed to add user $username." 10 60; return 1; }
    dialog --backtitle "ArchTUI" --title "User Password" --insecure --passwordbox "Enter password for $username:" 10 60 2>&1 >/dev/tty | passwd --stdin "$username" || { dialog --backtitle "Error" --msgbox "Failed to set password for user $username." 10 60; return 1; }

    # Add the user to sudoers (optional)
    usermod -aG wheel "$username" || { dialog --backtitle "Error" --msgbox "Failed to add $username to sudoers." 10 60; return 1; }
}

# Function to add additional pacman packages
add_additional_packages() {
    dialog --backtitle "ArchTUI" --title "Additional Packages" --inputbox "Enter additional pacman packages (space-separated):" 10 60 2>&1 >/dev/tty | xargs pacman -S --noconfirm
    if [ $? -ne 0 ]; then
        dialog --backtitle "Error" --msgbox "Failed to install additional packages. Please check your input and try again." 10 60
    else
        dialog --backtitle "Success" --msgbox "Additional packages installed successfully." 10 60
    fi
}

# Main function to display the menu and handle user choices
main() {
    check_root_privileges
    install_dialog || { echo "Failed to install dialog. Please install it manually and rerun the script."; exit 1; }

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
        choice=$(dialog --backtitle "ArchTUI" --title "Main Menu" --menu "Choose an option:" 15 60 5 "${dialog_options[@]}" 2>&1 >/dev/tty) || { echo "Failed to display menu. Exiting..."; exit 1; }

        # Handle user choice
        case $choice in
            1)
                # Partition Disk
                partition_disk || { dialog --backtitle "Error" --msgbox "Failed to partition the disk." 10 60; continue; }
                ;;
            2)
                # Install Base System
                install_base_system || { dialog --backtitle "Error" --msgbox "Failed to install the base system." 10 60; continue; }
                ;;
            3)
                # Configure System
                configure_system || { dialog --backtitle "Error" --msgbox "Failed to configure the system." 10 60; continue; }
                ;;
            4)
                # Add Additional Pacman Packages
                add_additional_packages || { dialog --backtitle "Error" --msgbox "Failed to add additional pacman packages." 10 60; continue; }
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