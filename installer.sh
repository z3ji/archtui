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

# Function to display the main menu
display_menu() {
    dialog --backtitle "ArchTUI" \
           --title "Main Menu" \
           --menu "Choose an option:" 15 60 4 \
           1 "Partition Disk" "Partition the disk to prepare for installation" \
           2 "Install Base System" "Install the base Arch Linux system" \
           3 "Configure System" "Configure system settings and user accounts" \
           4 "Exit" "Exit the installer" \
           2> menu_choice
}

# Function to handle disk partitioning
partition_disk() {
    # You can implement disk partitioning logic here
    dialog --msgbox "Partitioning Disk" 10 40
}

# Function to install the base system
install_base_system() {
    # You can implement base system installation logic here
    dialog --msgbox "Installing Base System" 10 40
}

# Function to configure the system
configure_system() {
    # You can implement system configuration logic here
    dialog --msgbox "Configuring System" 10 40
}

# Main function to execute the installer
main() {
    check_root_privileges
    install_dialog

    while true; do
        display_menu
        choice=$(<menu_choice)
        case $choice in
            1) partition_disk ;;
            2) install_base_system ;;
            3) configure_system ;;
            4) dialog --msgbox "Exiting..." 10 40; exit ;;
        esac
    done
}

# Start the installer
main
