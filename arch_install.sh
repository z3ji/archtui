#!/bin/bash

# Define the log file
LOG_FILE="/var/log/arch_install.log"

# Function to display dialog boxes with error handling
show_dialog() {
    dialog_output=$(dialog "$@")
    dialog_exit_status=$?
    if [ $dialog_exit_status -ne 0 ]; then
        dialog --backtitle "Error" --msgbox "Dialog command failed with exit status $dialog_exit_status. Please check your system configuration and try again." 10 60
        exit 1
    fi
    echo "$dialog_output"
}

# Function to log messages with timestamp
log_message() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

# Function to check if the user has root privileges
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        show_dialog --backtitle "Error" --msgbox "This script requires root privileges to install packages. Please run it as root or using sudo." 10 60
        exit 1
    fi
}

# Function to install dialog if not already installed
install_dialog() {
    if ! command -v dialog &> /dev/null; then
        log_message "Installing dialog..."
        pacman -S --noconfirm dialog
        if [ $? -ne 0 ]; then
            log_message "Failed to install dialog."
            show_dialog --backtitle "Error" --msgbox "Failed to install dialog. Please install it manually and rerun the script." 10 60
            exit 1
        fi
        log_message "Dialog installed successfully."
    fi
}

# Function to partition the disk
partition_disk() {
    # Prompt the user to choose the partition type
    partition_type=$(show_dialog --backtitle "ArchTUI" --title "Partition Type" --menu "Choose the partition type:" 10 60 2 \
        1 "Normal ext4 partition" \
        2 "Btrfs partition with Timeshift" 2>&1 >/dev/tty)

    # Check if user canceled
    if [ $? -ne 0 ]; then
        show_dialog --backtitle "Error" --msgbox "Partitioning canceled." 10 60
        return 1
    fi

    case $partition_type in
        1)
            # Normal ext4 partition
            log_message "Creating normal ext4 partition..."
            parted -s /dev/sda mklabel gpt || { log_message "Failed to create GPT partition table."; show_dialog --backtitle "Error" --msgbox "Failed to create GPT partition table." 10 60; return 1; }
            parted -s /dev/sda mkpart primary ext4 1MiB 100% || { log_message "Failed to create ext4 partition."; show_dialog --backtitle "Error" --msgbox "Failed to create ext4 partition." 10 60; return 1; }
            mkfs.ext4 /dev/sda1 || { log_message "Failed to format ext4 partition."; show_dialog --backtitle "Error" --msgbox "Failed to format ext4 partition." 10 60; return 1; }
            ;;
        2)
            # Btrfs partition with Timeshift
            log_message "Creating Btrfs partition with Timeshift..."
            parted -s /dev/sda mklabel gpt || { log_message "Failed to create GPT partition table."; show_dialog --backtitle "Error" --msgbox "Failed to create GPT partition table." 10 60; return 1; }
            parted -s /dev/sda mkpart primary btrfs 1MiB 100% || { log_message "Failed to create Btrfs partition."; show_dialog --backtitle "Error" --msgbox "Failed to create Btrfs partition." 10 60; return 1; }
            mkfs.btrfs /dev/sda1 || { log_message "Failed to format Btrfs partition."; show_dialog --backtitle "Error" --msgbox "Failed to format Btrfs partition." 10 60; return 1; }
            mount /dev/sda1 /mnt || { log_message "Failed to mount Btrfs partition."; show_dialog --backtitle "Error" --msgbox "Failed to mount Btrfs partition." 10 60; return 1; }
            btrfs subvolume create /mnt/@ || { log_message "Failed to create Btrfs subvolume."; show_dialog --backtitle "Error" --msgbox "Failed to create Btrfs subvolume." 10 60; return 1; }
            umount /mnt || { log_message "Failed to unmount Btrfs partition."; show_dialog --backtitle "Error" --msgbox "Failed to unmount Btrfs partition." 10 60; return 1; }
            mount -o subvol=@ /dev/sda1 /mnt || { log_message "Failed to mount Btrfs subvolume."; show_dialog --backtitle "Error" --msgbox "Failed to mount Btrfs subvolume." 10 60; return 1; }
            mkdir -p /mnt/timeshift || { log_message "Failed to create Timeshift directory."; show_dialog --backtitle "Error" --msgbox "Failed to create Timeshift directory." 10 60; return 1; }
            mount -o subvol=@timeshift /dev/sda1 /mnt/timeshift || { log_message "Failed to mount Timeshift subvolume."; show_dialog --backtitle "Error" --msgbox "Failed to mount Timeshift subvolume." 10 60; return 1; }
            ;;
        *)
            show_dialog --backtitle "Error" --msgbox "Invalid option selected." 10 60
            return 1
            ;;
    esac

    # Log success message
    log_message "Disk partitioning completed successfully."
}

# Function to install the base Arch Linux system
install_base_system() {
    log_message "Installing base system..."
    # Generate an fstab file
    genfstab -U /mnt >> /mnt/etc/fstab || { log_message "Failed to generate fstab file."; show_dialog --backtitle "Error" --msgbox "Failed to generate fstab file." 10 60; return 1; }

    # Change root to the new system
    arch-chroot /mnt /bin/bash <<EOF
    # Install base system packages
    if [[ $base_installation_option == "minimal" ]]; then
        pacman -S --noconfirm base base-devel linux linux-firmware btrfs-progs grub efibootmgr || { log_message "Failed to install minimal base system packages."; show_dialog --backtitle "Error" --msgbox "Failed to install minimal base system packages." 10 60; exit 1; }
    elif [[ $base_installation_option == "gnome" ]]; then
        pacman -S --noconfirm gnome gnome-extra networkmanager || { log_message "Failed to install GNOME desktop environment."; show_dialog --backtitle "Error" --msgbox "Failed to install GNOME desktop environment." 10 60; exit 1; }
    elif [[ $base_installation_option == "kde" ]]; then
        pacman -S --noconfirm plasma kde-applications networkmanager || { log_message "Failed to install KDE Plasma desktop environment."; show_dialog --backtitle "Error" --msgbox "Failed to install KDE Plasma desktop environment." 10 60; exit 1; }
    else
        log_message "Invalid base installation option."
        show_dialog --backtitle "Error" --msgbox "Invalid base installation option." 10 60
        exit 1
    fi

    # Configure and install GRUB
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || { log_message "Failed to install GRUB."; show_dialog --backtitle "Error" --msgbox "Failed to install GRUB." 10 60; exit 1; }
    grub-mkconfig -o /boot/grub/grub.cfg || { log_message "Failed to generate GRUB configuration."; show_dialog --backtitle "Error" --msgbox "Failed to generate GRUB configuration." 10 60; exit 1; }

    # Enable essential services (optional)
    systemctl enable NetworkManager || { log_message "Failed to enable NetworkManager service."; show_dialog --backtitle "Error" --msgbox "Failed to enable NetworkManager service." 10 60; exit 1; }
EOF

    # Check if chroot command succeeded
    if [ $? -ne 0 ]; then
        log_message "Failed to change root to the new system."
        show_dialog --backtitle "Error" --msgbox "Failed to change root to the new system." 10 60
        return 1
    fi

    # Log success message
    log_message "Base system installation completed successfully."
}

# Function to configure the system
configure_system() {
    # Set hostname
    hostname_input=$(show_dialog --backtitle "ArchTUI" --inputbox "Enter hostname:" 8 60 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then
        show_dialog --backtitle "Error" --msgbox "Hostname configuration cancelled." 10 60
        return 1
    fi
    echo "$hostname_input" > /etc/hostname || { log_message "Failed to set hostname."; show_dialog --backtitle "Error" --msgbox "Failed to set hostname." 10 60; return 1; }

    # Set up network (optional)
    # Configure network settings here...

    # Set root password
    root_password_input=$(show_dialog --backtitle "ArchTUI" --title "Root Password" --insecure --passwordbox "Enter root password:" 10 60 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then
        show_dialog --backtitle "Error" --msgbox "Root password configuration cancelled." 10 60
        return 1
    fi
    echo "$root_password_input" | passwd --stdin root || { log_message "Failed to set root password."; show_dialog --backtitle "Error" --msgbox "Failed to set root password." 10 60; return 1; }

    # Add a new user
    username_input=$(show_dialog --backtitle "ArchTUI" --inputbox "Enter username:" 8 60 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then
        show_dialog --backtitle "Error" --msgbox "User creation cancelled." 10 60
        return 1
    fi
    useradd -m "$username_input" || { log_message "Failed to add user $username_input."; show_dialog --backtitle "Error" --msgbox "Failed to add user $username_input." 10 60; return 1; }
    user_password_input=$(show_dialog --backtitle "ArchTUI" --title "User Password" --insecure --passwordbox "Enter password for $username_input:" 10 60 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then
        show_dialog --backtitle "Error" --msgbox "User password configuration cancelled." 10 60
        return 1
    fi
    echo "$user_password_input" | passwd --stdin "$username_input" || { log_message "Failed to set password for user $username_input."; show_dialog --backtitle "Error" --msgbox "Failed to set password for user $username_input." 10 60; return 1; }

    # Add the user to sudoers (optional)
    usermod -aG wheel "$username_input" || { log_message "Failed to add $username_input to sudoers."; show_dialog --backtitle "Error" --msgbox "Failed to add $username_input to sudoers." 10 60; return 1; }

    # Log success message
    log_message "System configuration completed successfully."
}

# Function to add additional pacman packages
add_additional_packages() {
    additional_packages=$(show_dialog --backtitle "ArchTUI" --title "Additional Packages" --inputbox "Enter additional pacman packages (space-separated):" 10 60 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then
        show_dialog --backtitle "Error" --msgbox "Package input cancelled. No additional packages installed." 10 60
        return 1
    fi

    # Check if input is not empty
    if [ -n "$additional_packages" ]; then
        log_message "Installing additional packages: $additional_packages"
        show_dialog --backtitle "ArchTUI" --title "Installing Packages" --infobox "Installing additional packages..." 5 50
        # Install additional packages
        echo "$additional_packages" | xargs pacman -S --noconfirm
        if [ $? -ne 0 ]; then
            log_message "Failed to install additional packages."
            show_dialog --backtitle "Error" --msgbox "Failed to install additional packages. Please check your input and try again." 10 60
            return 1
        else
            log_message "Additional packages installed successfully."
            show_dialog --backtitle "Success" --msgbox "Additional packages installed successfully." 10 60
        fi
    else
        show_dialog --backtitle "ArchTUI" --msgbox "No additional packages specified. Skipping installation." 10 60
    fi

    # Log success message
    log_message "Additional packages installed successfully."
}

# Main function to display the menu and handle user choices
main() {
    check_root_privileges
    install_dialog || { log_message "Failed to install dialog. Please install it manually and rerun the script."; exit 1; }

    # Start the installer
    log_message "Installer started."

    # Create an associative array to hold dialog menu options
    declare -A menu_options=(
        [1]="Partition Disk: Partition the disk to prepare for installation"
        [2]="Install Base System: Install the base Arch Linux system"
        [3]="Configure System: Configure system settings and user accounts"
        [4]="Add Additional Pacman Packages: Add additional packages using pacman"
        [5]="Exit: Exit the installer"
    )

    # Create an array to hold sorted dialog menu options
    dialog_options=()
    # Sort the keys in ascending order
    sorted_keys=($(echo "${!menu_options[@]}" | tr ' ' '\n' | sort -n))
    for key in "${sorted_keys[@]}"; do
        dialog_options+=("$key" "${menu_options[$key]}")
    done

    while true; do
        # Display the menu
        choice=$(show_dialog --backtitle "ArchTUI" --title "Main Menu" --menu "Choose an option:" 15 60 5 "${dialog_options[@]}" 2>&1 >/dev/tty) || { log_message "Failed to display menu. Exiting..."; exit 1; }

        # Handle user choice
        case $choice in
            1)
                # Partition Disk
                partition_disk || { show_dialog --backtitle "Error" --msgbox "Failed to partition the disk." 10 60; continue; }
                ;;
            2)
                # Install Base System
                install_base_system || { show_dialog --backtitle "Error" --msgbox "Failed to install the base system." 10 60; continue; }
                ;;
            3)
                # Configure System
                configure_system || { show_dialog --backtitle "Error" --msgbox "Failed to configure the system." 10 60; continue; }
                ;;
            4)
                # Add Additional Pacman Packages
                add_additional_packages || { show_dialog --backtitle "Error" --msgbox "Failed to add additional pacman packages." 10 60; continue; }
                ;;
            5)
                # Exit
                show_dialog --msgbox "Exiting..." 10 40
                exit
                ;;
            *)
                # If the user cancels or presses Escape, exit the installer
                show_dialog --msgbox "Exiting..." 10 40
                exit
                ;;
        esac
    done

    log_message "Installer completed."
}

# Start the installer
main
