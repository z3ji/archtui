#!/bin/bash

# Function to display the main menu
display_menu() {
    dialog --backtitle "ArchTUI" \
           --title "Main Menu" \
           --menu "Choose an option:" 15 60 4 \
           1 "Partition Disk" \
           2 "Install Base System" \
           3 "Configure System" \
           4 "Exit" \
           2> menu_choice
}

# Function to handle disk partitioning
partition_disk() {
    # You can implement disk partitioning logic here
    echo "Partitioning Disk"
}

# Function to install the base system
install_base_system() {
    # You can implement base system installation logic here
    echo "Installing Base System"
}

# Function to configure the system
configure_system() {
    # You can implement system configuration logic here
    echo "Configuring System"
}

# Main function to execute the installer
main() {
    while true; do
        display_menu
        choice=$(<menu_choice)
        case $choice in
            1) partition_disk ;;
            2) install_base_system ;;
            3) configure_system ;;
            4) echo "Exiting..."; exit ;;
        esac
    done
}

# Start the installer
main
