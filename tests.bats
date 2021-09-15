#!/usr/bin/env bats

# Load the script you want to test
load ./arch_install.sh

# Function to reset environment for each test
setup() {
    # Reset any environment variables or state modifications here
    unset BATS_TMPDIR
}

# Test error handling for invalid input in partition type selection
@test "Test error handling for invalid input in partition type selection" {
    # Mock the select_partition_type function to return invalid input
    select_partition_type() {
        echo "InvalidInput"
    }
    run select_partition_type
    [ "$status" -ne 0 ]
    [ "$output" = *"Error: Invalid input provided for partition type selection"* ]
}

# Test partition type selection
@test "Test partition type selection" {
    # Define test parameters
    declare -A tests=(
        ["UEFI"]="1"
        ["BIOS"]="1"
    )
    
    # Iterate over test parameters
    for type in "${!tests[@]}"; do
        run select_partition_type "$type"
        [ "$status" -eq 0 ]
        [ "$output" = "${tests[$type]}" ]
    done
}

# Test GRUB configuration
@test "Test GRUB configuration" {
    # Define test parameters
    declare -A tests=(
        ["UEFI"]="GRUB configured successfully for UEFI system"
        ["BIOS"]="GRUB configured successfully for BIOS system"
    )
    
    # Iterate over test parameters
    for type in "${!tests[@]}"; do
        # Mocking /sys/firmware/efi/efivars to simulate UEFI or BIOS system
        BATS_TMPDIR=$(mktemp -d)
        [ "$type" = "BIOS" ] && mkdir -p "$BATS_TMPDIR/sys/firmware/efi/efivars"
        
        run configure_grub
        [ "$status" -eq 0 ]
        [ "$output" = "${tests[$type]}" ]
    done
}

# Test ext4 partition creation
@test "Test ext4 partition creation" {
    # Mock the prompt_drive_selection function
    prompt_drive_selection() {
        echo "/dev/sda"
    }
    run create_ext4_partition
    [ "$status" -eq 0 ]
    [ "$output" = *"ext4 partition created successfully"* ]
}

# Test Btrfs partition creation
@test "Test Btrfs partition creation" {
    # Define test parameters
    declare -A tests=(
        ["/dev/sdb"]="Btrfs partition created successfully"
        ["/dev/sdc"]="Btrfs partition created successfully"
    )
    
    # Iterate over test parameters
    for device in "${!tests[@]}"; do
        prompt_drive_selection() {
            echo "$device"
        }
        run create_btrfs_partition
        [ "$status" -eq 0 ]
        [ "$output" = "${tests[$device]}" ]
    done
}

# Test base package installation
@test "Test base package installation" {
    # Define test parameters
    declare -A tests=(
        ["minimal"]="Base packages for minimal installation installed successfully"
        ["gnome"]="Base packages for gnome installation installed successfully"
        ["kde"]="Base packages for kde installation installed successfully"
        ["invalid"]="Error: Invalid input provided for desktop environment selection"
    )
    
    # Iterate over test parameters
    for desktop_env in "${!tests[@]}"; do
        prompt_desktop_environment() {
            echo "$desktop_env"
        }
        run install_base_packages
        [ "$status" -eq 0 ]
        [ "$output" = "${tests[$desktop_env]}" ]
    done
}

# Test NetworkManager service enablement
@test "Test NetworkManager service enablement" {
    run enable_network_manager
    [ "$status" -eq 0 ]
    [ "$output" = *"NetworkManager service enabled successfully"* ]
}

# Test hostname configuration
@test "Test hostname configuration" {
    run configure_hostname "test-hostname"
    [ "$status" -eq 0 ]
    [ "$output" = *"Hostname configured successfully"* ]
}

# Test root password setup
@test "Test root password setup" {
    run set_root_password "newrootpassword"
    [ "$status" -eq 0 ]
    [ "$output" = *"Root password set successfully"* ]
}

# Test new user creation
@test "Test new user creation" {
    run create_new_user "testuser" "testpassword"
    [ "$status" -eq 0 ]
    [ "$output" = *"User 'testuser' created successfully"* ]
}

# Test additional package installation
@test "Test additional package installation" {
    # Define test parameters
    declare -A tests=(
        ["vim git"]="Packages installed successfully"
        ["invalid_package"]="Error: Invalid input provided for additional packages"
    )
    
    # Iterate over test parameters
    for packages in "${!tests[@]}"; do
        prompt_additional_packages() {
            echo "$packages"
        }
        run install_additional_packages
        [ "$status" -eq 0 ]
        [ "$output" = "${tests[$packages]}" ]
    done
}