#!/bin/bash

# Define the log file
LOG_FILE="/var/log/arch_install.log"

# Function to log messages with timestamp
log_message() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

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
        log_message "Installing dialog..."
        pacman -S --noconfirm dialog
        if [ $? -ne 0 ]; then
            log_message "Failed to install dialog."
            dialog --backtitle "Error" --msgbox "Failed to install dialog. Please install it manually and rerun the script." 10 60
            exit 1
        fi
        log_message "Dialog installed successfully."
    fi
}

# Function to read command-line arguments
read_command_line_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --partition-type)
                PARTITION_TYPE="$2"
                shift 2
                ;;
            --base-installation)
                BASE_INSTALLATION_OPTION="$2"
                shift 2
                ;;
            --additional-packages)
                ADDITIONAL_PACKAGES="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Function to display usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --partition-type <type>         Specify partition type (1 for ext4, 2 for Btrfs)"
    echo "  --base-installation <option>    Specify base installation option (minimal, gnome, kde)"
    echo "  --additional-packages <list>    Specify additional packages to install"
}

# Function to read configuration from a file
read_configuration_file() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        source "$config_file"
    fi
}

# Validate hostname
validate_hostname() {
    local hostname_input="$1"
    if [[ ! $hostname_input =~ ^[a-zA-Z0-9.-]+$ ]]; then
        dialog --backtitle "Error" --msgbox "Invalid hostname. Please use only alphanumeric characters, hyphens, and dots." 10 60
        return 1
    fi
}

# Validate username
validate_username() {
    local username_input="$1"
    if [[ ! $username_input =~ ^[a-z_][a-z0-9_-]{0,30}$ ]]; then
        dialog --backtitle "Error" --msgbox "Invalid username. Please use only lowercase letters, digits, hyphens, and underscores. It must start with a letter or underscore and be 1-32 characters long." 10 60
        return 1
    fi
}

# Validate password
validate_password() {
    local password_input="$1"
    if [[ ${#password_input} -lt 8 ]]; then
        dialog --backtitle "Error" --msgbox "Password must be at least 8 characters long." 10 60
        return 1
    fi
}

# Function to handle partitioning of the disk
partition_disk() {
    # Check if EFI/UEFI or BIOS system
    if [ -d "/sys/firmware/efi/efivars" ]; then
        boot_type="UEFI"
    else
        boot_type="BIOS"
    fi

    # Partition type selection based on boot type
    if [ "$boot_type" = "UEFI" ]; then
        partition_type=$(select_partition_type_uefi)
    else
        partition_type=$(select_partition_type_bios)
    fi

    case $partition_type in
        1) create_ext4_partition ;;
        2) create_btrfs_partition ;;
        *) dialog --backtitle "Error" --msgbox "Invalid option selected." 10 60 ;;
    esac
}

# Function to select the partition type for UEFI systems
select_partition_type_uefi() {
    dialog --backtitle "ArchTUI" --title "Partition Type" --menu "Choose the partition type:" 10 60 2 \
        1 "Normal ext4 partition" \
        2 "Btrfs partition with Timeshift" 2>&1 >/dev/tty
    return $?
}

# Function to select the partition type for BIOS systems
select_partition_type_bios() {
    dialog --backtitle "ArchTUI" --title "Partition Type" --menu "Choose the partition type:" 10 60 1 \
        1 "Normal ext4 partition" 2>&1 >/dev/tty
    return $?
}

# Function to prompt user for drive selection
prompt_drive_selection() {
    local drive
    drive=$(dialog --backtitle "ArchTUI" --title "Drive Selection" --inputbox "Enter the drive (e.g., /dev/sda):" 8 60 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then
        dialog --backtitle "Error" --msgbox "Drive selection cancelled." 10 60
        return 1
    fi
    echo "$drive"
}

# Function to create an ext4 partition
create_ext4_partition() {
    log_message "Creating normal ext4 partition..."

    # Prompt user for drive selection
    local drive
    drive=$(prompt_drive_selection)
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Partition the selected drive
    parted -s "$drive" mklabel gpt || { log_message "Failed to create GPT partition table."; dialog --backtitle "Error" --msgbox "Failed to create GPT partition table. Please check your disk and try again." 10 60; return 1; }
    parted -s "$drive" mkpart primary ext4 1MiB 100% || { log_message "Failed to create ext4 partition."; dialog --backtitle "Error" --msgbox "Failed to create ext4 partition. Please check your disk and try again." 10 60; return 1; }
    mkfs.ext4 "${drive}1" || { log_message "Failed to format ext4 partition."; dialog --backtitle "Error" --msgbox "Failed to format ext4 partition. Please check your disk and try again." 10 60; return 1; }

    log_message "Normal ext4 partition created successfully."
}

# Function to create a Btrfs partition with Timeshift
create_btrfs_partition() {
    log_message "Creating Btrfs partition with Timeshift..."

    # Prompt user for drive selection
    local drive
    drive=$(prompt_drive_selection)
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Partition the selected drive
    parted -s "$drive" mklabel gpt || { log_message "Failed to create GPT partition table."; dialog --backtitle "Error" --msgbox "Failed to create GPT partition table. Please check your disk and try again." 10 60; return 1; }
    parted -s "$drive" mkpart primary btrfs 1MiB 100% || { log_message "Failed to create Btrfs partition."; dialog --backtitle "Error" --msgbox "Failed to create Btrfs partition. Please check your disk and try again." 10 60; return 1; }
    mkfs.btrfs "${drive}1" || { log_message "Failed to format Btrfs partition."; dialog --backtitle "Error" --msgbox "Failed to format Btrfs partition. Please check your disk and try again." 10 60; return 1; }

    # Mount the Btrfs partition
    mount "${drive}1" /mnt || { log_message "Failed to mount Btrfs partition."; dialog --backtitle "Error" --msgbox "Failed to mount Btrfs partition. Please check your disk and try again." 10 60; return 1; }

    # Create Btrfs subvolume
    btrfs subvolume create /mnt/@ || { log_message "Failed to create Btrfs subvolume."; dialog --backtitle "Error" --msgbox "Failed to create Btrfs subvolume. Please check your disk and try again." 10 60; return 1; }

    # Unmount the partition
    umount /mnt || { log_message "Failed to unmount Btrfs partition."; dialog --backtitle "Error" --msgbox "Failed to unmount Btrfs partition. Please check your disk and try again." 10 60; return 1; }

    # Mount the Btrfs subvolume
    mount -o subvol=@ "${drive}1" /mnt || { log_message "Failed to mount Btrfs subvolume."; dialog --backtitle "Error" --msgbox "Failed to mount Btrfs subvolume. Please check your disk and try again." 10 60; return 1; }

    # Create Timeshift directory and mount Timeshift subvolume
    mkdir -p /mnt/timeshift || { log_message "Failed to create Timeshift directory."; dialog --backtitle "Error" --msgbox "Failed to create Timeshift directory. Please check your disk and try again." 10 60; return 1; }
    mount -o subvol=@timeshift "${drive}1" /mnt/timeshift || { log_message "Failed to mount Timeshift subvolume."; dialog --backtitle "Error" --msgbox "Failed to mount Timeshift subvolume. Please check your disk and try again." 10 60; return 1; }

    log_message "Btrfs partition with Timeshift created successfully."
}

# Function to install base system packages based on the installation option
install_base_packages() {
    local base_installation_option="$1"
    case $base_installation_option in
        minimal|gnome|kde)
            pacman -S --noconfirm base base-devel linux linux-firmware btrfs-progs grub efibootmgr networkmanager ;;
        gnome)
            pacman -S --noconfirm gnome gnome-extra ;;
        kde)
            pacman -S --noconfirm plasma kde-applications ;;
        *)
            log_message "Invalid base installation option: $base_installation_option"
            dialog --backtitle "Error" --msgbox "Invalid base installation option: $base_installation_option. Please select a valid option." 10 60
            exit 1 ;;
    esac
}

# Function to configure and install GRUB
configure_grub() {
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || { log_message "Failed to install GRUB."; dialog --backtitle "Error" --msgbox "Failed to install GRUB. Please check your bootloader configuration and try again." 10 60; exit 1; }
    grub-mkconfig -o /boot/grub/grub.cfg || { log_message "Failed to generate GRUB configuration."; dialog --backtitle "Error" --msgbox "Failed to generate GRUB configuration. Please check your bootloader configuration and try again." 10 60; exit 1; }
}

# Function to enable essential services
enable_services() {
    systemctl enable NetworkManager || { log_message "Failed to enable NetworkManager service."; dialog --backtitle "Error" --msgbox "Failed to enable NetworkManager service. Please check your network configuration and try again." 10 60; exit 1; }
}

# Function to install the base Arch Linux system
install_base_system() {
    log_message "Installing base system..."

    # Mount /mnt to "$drive"
    mount "${drive}1" /mnt || { log_message "Failed to mount /mnt."; dialog --backtitle "Error" --msgbox "Failed to mount /mnt. Please check your system configuration and try again." 10 60; return 1; }

    # Check if /mnt is mounted
    if ! mountpoint -q /mnt; then
        log_message "Error: /mnt is not a mount point. Please mount the root filesystem to /mnt before proceeding."
        dialog --backtitle "Error" --msgbox "/mnt is not a mount point. Please mount the root filesystem to /mnt before proceeding." 10 60
        return 1
    fi

    # Generate an fstab file
    genfstab -U /mnt >> /mnt/etc/fstab || { log_message "Failed to generate fstab file."; dialog --backtitle "Error" --msgbox "Failed to generate fstab file. Please check your system configuration and try again." 10 60; return 1; }

    # Change root to the new system
    arch-chroot /mnt /bin/bash <<EOF
    # Install base system packages
    install_base_packages "$base_installation_option" || exit 1

    # Configure and install GRUB
    configure_grub || exit 1

    # Enable essential services
    enable_services || exit 1
EOF

    local chroot_exit_status=$?
    if [ $chroot_exit_status -ne 0 ]; then
        log_message "Failed to change root to the new system."
        dialog --backtitle "Error" --msgbox "Failed to change root to the new system. Please check your system configuration and try again." 10 60
        return 1
    fi

    # Log success message
    log_message "Base system installation completed successfully."
}

# Function to set hostname
set_hostname() {
    local hostname_input
    hostname_input=$(dialog --backtitle "ArchTUI" --inputbox "Enter hostname:" 8 60 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then
        dialog --backtitle "Error" --msgbox "Hostname configuration cancelled." 10 60
        return 1
    fi
    validate_hostname "$hostname_input" || return 1
    echo "$hostname_input" > /etc/hostname || { log_message "Failed to set hostname."; dialog --backtitle "Error" --msgbox "Failed to set hostname. Please check your input and try again." 10 60; return 1; }
}

# Function to set root password
set_root_password() {
    local root_password_input
    root_password_input=$(dialog --backtitle "ArchTUI" --title "Root Password" --insecure --passwordbox "Enter root password:" 10 60 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then
        dialog --backtitle "Error" --msgbox "Root password configuration cancelled." 10 60
        return 1
    fi
    validate_password "$root_password_input" || return 1
    echo "$root_password_input" | passwd --stdin root || { log_message "Failed to set root password."; dialog --backtitle "Error" --msgbox "Failed to set root password. Please check your input and try again." 10 60; return 1; }
}

# Function to add a new user
add_new_user() {
    local username_input user_password_input
    username_input=$(dialog --backtitle "ArchTUI" --inputbox "Enter username:" 8 60 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then
        dialog --backtitle "Error" --msgbox "User creation cancelled." 10 60
        return 1
    fi
    validate_username "$username_input" || return 1
    useradd -m "$username_input" || { log_message "Failed to add user $username_input."; dialog --backtitle "Error" --msgbox "Failed to add user $username_input. Please check your input and try again." 10 60; return 1; }
    user_password_input=$(dialog --backtitle "ArchTUI" --title "User Password" --insecure --passwordbox "Enter password for $username_input:" 10 60 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then
        dialog --backtitle "Error" --msgbox "User password configuration cancelled." 10 60
        return 1
    fi
    validate_password "$user_password_input" || return 1
    echo "$user_password_input" | passwd --stdin "$username_input" || { log_message "Failed to set password for user $username_input."; dialog --backtitle "Error" --msgbox "Failed to set password for user $username_input. Please check your input and try again." 10 60; return 1; }
    usermod -aG wheel "$username_input" || { log_message "Failed to add $username_input to sudoers."; dialog --backtitle "Error" --msgbox "Failed to add $username_input to sudoers. Please check your system configuration and try again." 10 60; return 1; }
}

# Function to configure the system
configure_system() {
    log_message "Configuring system..."
    
    # Set hostname
    set_hostname || return 1

    # Set root password
    set_root_password || return 1

    # Add a new user
    add_new_user || return 1

    # Log success message
    log_message "System configuration completed successfully."
}

# Function to get additional pacman packages input from user
get_additional_packages_input() {
    local additional_packages
    additional_packages=$(dialog --backtitle "ArchTUI" --title "Additional Packages" --inputbox "Enter additional pacman packages (space-separated):" 10 60 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then
        dialog --backtitle "Error" --msgbox "Package input cancelled. No additional packages installed." 10 60
        return 1
    fi
    echo "$additional_packages"
}

# Function to install additional pacman packages
install_additional_packages() {
    local additional_packages="$1"
    # Check if input is not empty
    if [ -n "$additional_packages" ]; then
        log_message "Installing additional packages: $additional_packages"
        dialog --backtitle "ArchTUI" --title "Installing Packages" --infobox "Installing additional packages..." 5 50
        # Install additional packages
        echo "$additional_packages" | xargs pacman -S --noconfirm
        if [ $? -ne 0 ]; then
            log_message "Failed to install additional packages."
            dialog --backtitle "Error" --msgbox "Failed to install additional packages. Please check your input and try again." 10 60
            return 1
        else
            log_message "Additional packages installed successfully."
            dialog --backtitle "Success" --msgbox "Additional packages installed successfully." 10 60
        fi
    else
        dialog --backtitle "ArchTUI" --msgbox "No additional packages specified. Skipping installation." 10 60
    fi
}

# Function to add additional pacman packages
add_additional_packages() {
    log_message "Adding additional pacman packages..."
    local additional_packages
    additional_packages=$(get_additional_packages_input) || return 1
    install_additional_packages "$additional_packages" || return 1
    log_message "Additional packages installation completed successfully."
}

# Function to display the menu
show_menu() {
    declare -A menu_options=(
        [1]="Partition Disk"
        [2]="Install Base System"
        [3]="Configure System"
        [4]="Add Additional Pacman Packages"
        [5]="Reboot System"
        [q]="Exit"
    )

    dialog_options=()
    sorted_keys=($(echo "${!menu_options[@]}" | tr ' ' '\n' | sort -n))
    for key in "${sorted_keys[@]}"; do
        if [[ $key == [[:digit:]] ]]; then
            dialog_options+=("$key" "${menu_options[$key]}")
        fi
    done
    for key in "${sorted_keys[@]}"; do
        if [[ $key == [[:alpha:]] ]]; then
            dialog_options+=("$key" "${menu_options[$key]}")
        fi
    done

    dialog --backtitle "ArchTUI" --title "Main Menu" --menu "Choose an option:" 15 60 6 "${dialog_options[@]}" 2>&1 >/dev/tty
}

# Function to handle user choices
handle_choice() {
    local choice="$1"
    case $choice in
        1) partition_disk ;;
        2) install_base_system ;;
        3) configure_system ;;
        4) add_additional_packages ;;
        5) reboot ;;
        q|Q) dialog --msgbox "Exiting..." 10 40; exit ;;
    esac
}

# Main function to display the menu and handle user choices
main() {
    # Read command-line arguments
    read_command_line_arguments "$@"

    # Start the installer
    check_root_privileges
    install_dialog || { log_message "Failed to install dialog. Please install it manually and rerun the script."; exit 1; }

    # Read the configuration file
    read_configuration_file

    # Check if the config file exists and source it
    config_file="$PWD/arch_install.conf"
    if [ -f "$config_file" ]; then
        source "$config_file"
        # Check if required variables are set in the config file
        if [ -z "$PARTITION_TYPE" ] || [ -z "$BASE_INSTALLATION_OPTION" ] || [ -z "$ADDITIONAL_PACKAGES" ]; then
            log_message "Error: Configuration file is missing required variables. Please check the configuration file and try again."
            exit 1
        fi
    else
        log_message "Error: Configuration file not found. Please make sure 'arch_install.conf' exists in the root directory of the script."
        exit 1
    fi

    # Start the installer
    log_message "Installer started."

    # Menu loop
    while true; do
        choice=$(show_menu)
        handle_choice "$choice"
    done

    log_message "Installer completed."
}

# Start the installer
main