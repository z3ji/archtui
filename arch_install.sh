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
    # Check if the effective user ID is not 0 (root)
    if [[ $EUID -ne 0 ]]; then
        # Display an error message using dialog
        dialog --backtitle "Error" --msgbox "This script requires root privileges to install packages. Please run it as root or using sudo." 10 60
        # Exit with a non-zero status code
        exit 1
    fi
}

# Function to retry a command with a specified error message
retry_command() {
    local command="$1"
    local error_message="$2"
    local max_attempts=3
    local attempt=1
    # Retry the command up to the maximum number of attempts
    while [ $attempt -le $max_attempts ]; do
        log_message "Attempting command: $command (Attempt $attempt)"
        # Execute the command using eval
        eval "$command"
        # Check the exit status of the command
        if [ $? -eq 0 ]; then
            # If successful, log a success message and return
            log_message "Command executed successfully."
            return 0
        else
            # If failed, log an error message and increment the attempt count
            log_message "Command failed: $error_message"
            ((attempt++))
            # Wait for a short duration before retrying
            sleep 1
        fi
    done
    # If maximum attempts reached, log an error message and display an error dialog
    log_message "Maximum attempts reached. Command failed: $error_message"
    dialog --backtitle "Error" --msgbox "Failed to execute command after multiple attempts. Please check your system and try again." 10 60
    # Return with a non-zero status code
    return 1
}

# Function to retry a partition operation with a specified number of retries
retry_partition() {
    local operation=$1
    local max_retries=3
    local retry_count=0

    # Retry the operation until successful or maximum retries reached
    until $operation || [ $retry_count -eq $max_retries ]; do
        ((retry_count++))
        dialog --backtitle "Error" --msgbox "Operation failed. Retrying ($retry_count/$max_retries)..." 10 60
    done

    # If maximum retries reached, display an error dialog
    if [ $retry_count -eq $max_retries ]; then
        dialog --backtitle "Error" --msgbox "Operation failed after $max_retries attempts. Please check your disk and try again." 10 60
        return 1
    fi

    # Return success if operation was successful
    return 0
}

# Function to install dialog if not already installed
install_dialog() {
    # Check if dialog is installed
    if ! command -v dialog &> /dev/null; then
        # If not installed, log a message and attempt to install dialog
        log_message "Installing dialog..."
        pacman -S --noconfirm dialog
        # Check the exit status of the installation command
        if [ $? -ne 0 ]; then
            # If installation failed, log an error message and display an error dialog
            log_message "Failed to install dialog."
            dialog --backtitle "Error" --msgbox "Failed to install dialog. Please install it manually and rerun the script." 10 60
            # Exit with a non-zero status code
            exit 1
        fi
        # Log a success message if installation was successful
        log_message "Dialog installed successfully."
    fi
}

# Function to read command-line arguments
read_command_line_arguments() {
    # Loop through all command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --partition-type)
                # Read partition type from command line
                PARTITION_TYPE="$2"
                shift 2
                ;;
            --base-installation)
                # Read base installation option from command line
                BASE_INSTALLATION_OPTION="$2"
                shift 2
                ;;
            --additional-packages)
                # Read additional packages list from command line
                ADDITIONAL_PACKAGES="$2"
                shift 2
                ;;
            *)
                # Display an error message for unknown options and exit with a non-zero status code
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Function to display usage information
show_usage() {
    # Display script usage information
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --partition-type <type>         Specify partition type (1 for ext4, 2 for Btrfs)"
    echo "  --base-installation <option>    Specify base installation option (minimal, gnome, kde)"
    echo "  --additional-packages <list>    Specify additional packages to install"
}

# Function to read configuration from a file
read_configuration_file() {
    local config_file="$1"
    # Check if the configuration file exists
    if [ -f "$config_file" ]; then
        # Source the configuration file
        source "$config_file"
    fi
}

# Validate hostname
validate_hostname() {
    local hostname_input="$1"
    # Validate the hostname format using a regular expression
    if [[ ! $hostname_input =~ ^[a-zA-Z0-9.-]+$ ]]; then
        # If invalid, display an error dialog
        dialog --backtitle "Error" --msgbox "Invalid hostname. Please use only alphanumeric characters, hyphens, and dots." 10 60
        # Return with a non-zero status code
        return 1
    fi
}

# Validate username
validate_username() {
    local username_input="$1"
    # Validate the username format using a regular expression
    if [[ ! $username_input =~ ^[a-z_][a-z0-9_-]{0,30}$ ]]; then
        # If invalid, display an error dialog
        dialog --backtitle "Error" --msgbox "Invalid username. Please use only lowercase letters, digits, hyphens, and underscores. It must start with a letter or underscore and be 1-32 characters long." 10 60
        # Return with a non-zero status code
        return 1
    fi
}

# Validate password
validate_password() {
    local password_input="$1"
    # Check if the password length is less than 8 characters
    if [[ ${#password_input} -lt 8 ]]; then
        # If less than 8 characters, display an error dialog
        dialog --backtitle "Error" --msgbox "Password must be at least 8 characters long." 10 60
        # Return with a non-zero status code
        return 1
    fi
}

# Function to select the partition type based on the detected boot type
select_partition_type() {
    # Detect the boot type (UEFI or BIOS)
    local boot_type
    if [ -d "/sys/firmware/efi/efivars" ]; then
        boot_type="UEFI"
    else
        boot_type="BIOS"
    fi

    # Display a dialog to select the partition type based on the boot type
    case $boot_type in
        UEFI)
            dialog_title="Partition Type (UEFI)"
            menu_options=("1" "Normal ext4 partition" "2" "Btrfs partition with Timeshift")
            ;;
        BIOS)
            dialog_title="Partition Type (BIOS)"
            menu_options=("1" "Normal ext4 partition")
            ;;
    esac

    # Display the menu dialog and store the selected option
    selected_option=$(dialog --backtitle "ArchTUI" --title "$dialog_title" --menu "Choose the partition type:" 10 60 ${#menu_options[@]} "${menu_options[@]}" 2>&1 >/dev/tty)

    # Return the selected option
    echo "$selected_option"
}

# Function to handle partitioning of the disk with retry mechanism
partition_disk() {
    # Select the partition type
    local partition_type=$(select_partition_type)
    
    # Based on the selected partition type, call the corresponding partition creation function
    case $partition_type in
        1) retry_partition create_ext4_partition ;;
        2) retry_partition create_btrfs_partition ;;
        *) 
            # Display an error message for invalid option
            dialog --backtitle "Error" --msgbox "Invalid option selected." 10 60 
            return 1
            ;;
    esac

    # After partitioning, call install_base_system with the root partition
    install_base_system "$root_partition"
}

# Function to prompt user for drive selection with retry mechanism
prompt_drive_selection() {
    local drive

    # Prompt user to enter the drive
    drive=$(dialog --backtitle "ArchTUI" --title "Drive Selection" --inputbox "Enter the drive (e.g., /dev/sda):" 8 60 2>&1 >/dev/tty)

    # Check if the dialog was canceled
    if [ $? -ne 0 ]; then
        dialog --backtitle "Error" --msgbox "Drive selection cancelled." 10 60
        return 1
    fi
    
    # Validate drive input using regex
    if ! [[ "$drive" =~ ^/dev/[a-z]{3}$ ]]; then
        dialog --backtitle "Error" --msgbox "Invalid drive name. Please enter a valid drive name (e.g., /dev/sda)." 10 60
        return 1
    fi
    
    echo "$drive"
}

# Function to create an ext4 partition
create_ext4_partition() {
    log_message "Creating normal ext4 partition..."

    # Prompt user for drive selection
    local drive
    if ! drive=$(prompt_drive_selection); then
        log_message "Partition creation cancelled."
        return 1
    fi

    # Partition the selected drive
    if ! parted -s "$drive" mklabel gpt; then
        log_message "Failed to create GPT partition table for $drive."
        dialog --backtitle "Error" --msgbox "Failed to create GPT partition table for $drive. Please check your disk and try again." 10 60
        return 1
    fi

    if ! parted -s "$drive" mkpart primary ext4 1MiB 100%; then
        log_message "Failed to create ext4 partition on $drive."
        dialog --backtitle "Error" --msgbox "Failed to create ext4 partition on $drive. Please check your disk and try again." 10 60
        return 1
    fi

    if ! mkfs.ext4 "${drive}1"; then
        log_message "Failed to format ext4 partition on $drive."
        dialog --backtitle "Error" --msgbox "Failed to format ext4 partition on $drive. Please check your disk and try again." 10 60
        return 1
    fi

    log_message "Normal ext4 partition created successfully on $drive."
    dialog --backtitle "Success" --msgbox "Normal ext4 partition created successfully on $drive." 10 60
}

# Function to create a Btrfs partition with Timeshift
create_btrfs_partition() {
    log_message "Creating Btrfs partition with Timeshift..."

    # Prompt user for drive selection
    local drive
    if ! drive=$(prompt_drive_selection); then
        return 1
    fi

    # Partition the selected drive
    if ! parted -s "$drive" mklabel gpt; then
        log_message "Failed to create GPT partition table."
        dialog --backtitle "Error" --msgbox "Failed to create GPT partition table. Please check your disk and try again." 10 60
        return 1
    fi

    if ! parted -s "$drive" mkpart primary btrfs 1MiB 100%; then
        log_message "Failed to create Btrfs partition."
        dialog --backtitle "Error" --msgbox "Failed to create Btrfs partition. Please check your disk and try again." 10 60
        return 1
    fi

    if ! mkfs.btrfs "${drive}1"; then
        log_message "Failed to format Btrfs partition."
        dialog --backtitle "Error" --msgbox "Failed to format Btrfs partition. Please check your disk and try again." 10 60
        return 1
    fi

    # Mount the Btrfs partition
    if ! mount "${drive}1" /mnt; then
        log_message "Failed to mount Btrfs partition."
        dialog --backtitle "Error" --msgbox "Failed to mount Btrfs partition. Please check your disk and try again." 10 60
        return 1
    fi

    # Create Btrfs subvolume
    if ! btrfs subvolume create /mnt/@; then
        log_message "Failed to create Btrfs subvolume."
        dialog --backtitle "Error" --msgbox "Failed to create Btrfs subvolume. Please check your disk and try again." 10 60
        umount /mnt || true
        return 1
    fi

    # Unmount the partition
    if ! umount /mnt; then
        log_message "Failed to unmount Btrfs partition."
        dialog --backtitle "Error" --msgbox "Failed to unmount Btrfs partition. Please check your disk and try again." 10 60
        return 1
    fi

    # Mount the Btrfs subvolume
    if ! mount -o subvol=@ "${drive}1" /mnt; then
        log_message "Failed to mount Btrfs subvolume."
        dialog --backtitle "Error" --msgbox "Failed to mount Btrfs subvolume. Please check your disk and try again." 10 60
        return 1
    fi

    # Create Timeshift directory and mount Timeshift subvolume
    if ! mkdir -p /mnt/timeshift; then
        log_message "Failed to create Timeshift directory."
        dialog --backtitle "Error" --msgbox "Failed to create Timeshift directory. Please check your disk and try again." 10 60
        umount /mnt || true
        return 1
    fi

    if ! mount -o subvol=@timeshift "${drive}1" /mnt/timeshift; then
        log_message "Failed to mount Timeshift subvolume."
        dialog --backtitle "Error" --msgbox "Failed to mount Timeshift subvolume. Please check your disk and try again." 10 60
        umount /mnt || true
        return 1
    fi

    log_message "Btrfs partition with Timeshift created successfully."
}

# Function to install base system packages based on the installation option
install_base_packages() {
    local base_installation_option="$1"
    local base_packages="base base-devel linux linux-firmware btrfs-progs grub efibootmgr networkmanager"

    case $base_installation_option in
        minimal) ;;
        gnome) base_packages+=" gnome gnome-extra" ;;
        kde) base_packages+=" plasma kde-applications" ;;
        *)
            log_message "Invalid base installation option: $base_installation_option"
            dialog --backtitle "Error" --msgbox "Invalid base installation option: $base_installation_option. Please select a valid option." 10 60
            exit 1 ;;
    esac

    log_message "Installing base system packages..."
    if ! pacman -S --noconfirm $base_packages; then
        log_message "Failed to install base system packages."
        dialog --backtitle "Error" --msgbox "Failed to install base system packages. Please check your internet connection and try again." 10 60
        exit 1
    fi

    log_message "Base system packages installed successfully."
}

# Function to configure and install GRUB
configure_grub() {
    # Check if EFI/UEFI or BIOS system
    if [ -d "/sys/firmware/efi/efivars" ]; then
        # For UEFI systems
        log_message "Configuring GRUB for UEFI..."
        pacman -S --noconfirm grub efibootmgr || { log_message "Failed to install GRUB packages for UEFI."; dialog --backtitle "Error" --msgbox "Failed to install GRUB packages for UEFI. Please check your system configuration and try again." 10 60; exit 1; }
        mkdir /boot/efi || { log_message "Failed to create EFI directory."; dialog --backtitle "Error" --msgbox "Failed to create EFI directory. Please check your system configuration and try again." 10 60; exit 1; }
        mount "$PARTITION_TYPE" /boot/efi || { log_message "Failed to mount EFI partition."; dialog --backtitle "Error" --msgbox "Failed to mount EFI partition. Please check your system configuration and try again." 10 60; exit 1; }
        grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi || { log_message "Failed to install GRUB to EFI partition."; dialog --backtitle "Error" --msgbox "Failed to install GRUB to EFI partition. Please check your system configuration and try again." 10 60; exit 1; }
        grub-mkconfig -o /boot/grub/grub.cfg || { log_message "Failed to generate GRUB configuration file."; dialog --backtitle "Error" --msgbox "Failed to generate GRUB configuration file. Please check your system configuration and try again." 10 60; exit 1; }
    else
        # For BIOS systems
        log_message "Configuring GRUB for BIOS..."
        pacman -S --noconfirm grub || { log_message "Failed to install GRUB packages for BIOS."; dialog --backtitle "Error" --msgbox "Failed to install GRUB packages for BIOS. Please check your system configuration and try again." 10 60; exit 1; }
        grub-install --target=i386-pc "$PARTITION_TYPE" || { log_message "Failed to install GRUB to MBR."; dialog --backtitle "Error" --msgbox "Failed to install GRUB to MBR. Please check your system configuration and try again." 10 60; exit 1; }
        grub-mkconfig -o /boot/grub/grub.cfg || { log_message "Failed to generate GRUB configuration file."; dialog --backtitle "Error" --msgbox "Failed to generate GRUB configuration file. Please check your system configuration and try again." 10 60; exit 1; }
    fi
}

# Function to enable essential services
enable_services() {
    systemctl enable NetworkManager || { log_message "Failed to enable NetworkManager service."; dialog --backtitle "Error" --msgbox "Failed to enable NetworkManager service. Please check your network configuration and try again." 10 60; exit 1; }
}

# Function to install the base Arch Linux system
install_base_system() {
    log_message "Installing base system..."
    
    local root_partition="$1"
    
    # Mount root partition
    mount "$root_partition" /mnt || { log_message "Failed to mount root partition."; dialog --backtitle "Error" --msgbox "Failed to mount root partition. Please check your system configuration and try again." 10 60; return 1; }

    # Check if /mnt is mounted
    if ! mountpoint -q /mnt; then
        log_message "Error: /mnt is not a mount point."
        dialog --backtitle "Error" --msgbox "/mnt is not a mount point. Please check your system configuration and try again." 10 60
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

    # Validate hostname input
    if ! validate_hostname "$hostname_input"; then
        return 1
    fi

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

    # Validate root password input
    if ! validate_password "$root_password_input"; then
        return 1
    fi

    echo "$root_password_input" | passwd --stdin root || { log_message "Failed to set root password."; dialog --backtitle "Error" --msgbox "Failed to set root password. Please check your input and try again." 10 60; return 1; }
}

# Function to add a new user
add_new_user() {
    local username_input user_password_input

    # Prompt user for username
    username_input=$(dialog --backtitle "ArchTUI" --inputbox "Enter username:" 8 60 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then
        dialog --backtitle "Error" --msgbox "User creation cancelled." 10 60
        return 1
    fi

    # Validate username
    if ! validate_username "$username_input"; then
        return 1
    fi

    # Create user
    useradd -m "$username_input" || { log_message "Failed to add user $username_input."; dialog --backtitle "Error" --msgbox "Failed to add user $username_input. Please check your input and try again." 10 60; return 1; }

    # Prompt user for password
    user_password_input=$(dialog --backtitle "ArchTUI" --title "User Password" --insecure --passwordbox "Enter password for $username_input:" 10 60 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then
        dialog --backtitle "Error" --msgbox "User password configuration cancelled." 10 60
        return 1
    fi

    # Validate user password
    if ! validate_password "$user_password_input"; then
        return 1
    fi

    # Set user password
    echo "$user_password_input" | passwd --stdin "$username_input" || { log_message "Failed to set password for user $username_input."; dialog --backtitle "Error" --msgbox "Failed to set password for user $username_input. Please check your input and try again." 10 60; return 1; }

    # Add user to sudoers
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

    # Prompt user for additional packages input
    additional_packages=$(dialog --backtitle "ArchTUI" --title "Additional Packages" --inputbox "Enter additional pacman packages (space-separated):" 10 60 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then
        # Handle cancellation
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
        if ! pacman -S --noconfirm $additional_packages; then
            # Handle installation failure
            log_message "Failed to install additional packages."
            dialog --backtitle "Error" --msgbox "Failed to install additional packages. Please check your input and try again." 10 60
            return 1
        else
            # Installation successful
            log_message "Additional packages installed successfully."
            dialog --backtitle "Success" --msgbox "Additional packages installed successfully." 10 60
        fi
    else
        # No additional packages specified
        dialog --backtitle "ArchTUI" --msgbox "No additional packages specified. Skipping installation." 10 60
    fi
}

# Function to add additional pacman packages
add_additional_packages() {
    log_message "Adding additional pacman packages..."
    local additional_packages
    # Get additional packages input from user
    additional_packages=$(get_additional_packages_input) || return 1
    # Install additional packages
    install_additional_packages "$additional_packages" || return 1
    log_message "Additional packages installation completed successfully."
}

# Function to display the menu
show_menu() {
    # Define menu options
    declare -A menu_options=(
        [1]="Partition Disk"
        [2]="Install Base System"
        [3]="Configure System"
        [4]="Add Additional Pacman Packages"
        [5]="Reboot System"
        [q]="Exit"
    )

    # Prepare dialog options array
    dialog_options=() # Initialize array to hold dialog options
    numeric_keys=()   # Initialize array to hold numeric keys

    # Loop through menu options to find numeric keys
    for key in "${!menu_options[@]}"; do
        if [[ $key =~ ^[0-9]+$ ]]; then
            numeric_keys+=("$key")  # Store numeric keys
        fi
    done

    # Sort numeric keys numerically
    sorted_numeric_keys=($(printf '%s\n' "${numeric_keys[@]}" | sort -n))

    # Add sorted numeric keys to dialog options array
    for key in "${sorted_numeric_keys[@]}"; do
        dialog_options+=("$key" "${menu_options[$key]}")
    done

    # Add remaining keys (non-numeric) to dialog options array
    for key in "${!menu_options[@]}"; do
        if [[ ! "${numeric_keys[@]}" =~ $key ]]; then
            dialog_options+=("$key" "${menu_options[$key]}")
        fi
    done

    # Display menu using dialog
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