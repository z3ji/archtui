#!/usr/bin/env bats

# Load the script you want to test
load ./arch_install.sh

@test "Test partition type selection for UEFI" {
    run select_partition_type
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "Test partition type selection for BIOS" {
    # Mocking /sys/firmware/efi/efivars to simulate BIOS system
    BATS_TMPDIR=$(mktemp -d)
    mkdir -p "$BATS_TMPDIR/sys/firmware/efi/efivars"
    run select_partition_type
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "Test GRUB configuration for UEFI system" {
    # Mocking /sys/firmware/efi/efivars to simulate UEFI system
    BATS_TMPDIR=$(mktemp -d)
    mkdir -p "$BATS_TMPDIR/sys/firmware/efi/efivars"
    run configure_grub
    [ "$status" -eq 0 ]
    [ "$output" = *"GRUB configured successfully for UEFI system"* ]
}

@test "Test GRUB configuration for BIOS system" {
    # Mocking absence of /sys/firmware/efi/efivars to simulate BIOS system
    BATS_TMPDIR=$(mktemp -d)
    run configure_grub
    [ "$status" -eq 0 ]
    [ "$output" = *"GRUB configured successfully for BIOS system"* ]
}

@test "Test ext4 partition creation" {
    # Mock the prompt_drive_selection function
    prompt_drive_selection() {
        echo "/dev/sda"
    }
    run create_ext4_partition
    [ "$status" -eq 0 ]
    [ "$output" = *"ext4 partition created successfully"* ]
}

@test "Test Btrfs partition creation" {
    # Mock the prompt_drive_selection function
    prompt_drive_selection() {
        echo "/dev/sdb"
    }
    run create_btrfs_partition
    [ "$status" -eq 0 ]
    [ "$output" = *"Btrfs partition created successfully"* ]
}

@test "Test base package installation for minimal installation" {
    # Mock the prompt_desktop_environment function
    prompt_desktop_environment() {
        echo "minimal"
    }
    run install_base_packages
    [ "$status" -eq 0 ]
    [ "$output" = *"Base packages for minimal installation installed successfully"* ]
}

@test "Test base package installation for gnome installation" {
    # Mock the prompt_desktop_environment function
    prompt_desktop_environment() {
        echo "gnome"
    }
    run install_base_packages
    [ "$status" -eq 0 ]
    [ "$output" = *"Base packages for gnome installation installed successfully"* ]
}

@test "Test base package installation for kde installation" {
    # Mock the prompt_desktop_environment function
    prompt_desktop_environment() {
        echo "kde"
    }
    run install_base_packages
    [ "$status" -eq 0 ]
    [ "$output" = *"Base packages for kde installation installed successfully"* ]
}

@test "Test NetworkManager service enablement" {
    run enable_network_manager
    [ "$status" -eq 0 ]
    [ "$output" = *"NetworkManager service enabled successfully"* ]
}

@test "Test hostname configuration" {
    run configure_hostname "test-hostname"
    [ "$status" -eq 0 ]
    [ "$output" = *"Hostname configured successfully"* ]
}

@test "Test root password setup" {
    run set_root_password "newrootpassword"
    [ "$status" -eq 0 ]
    [ "$output" = *"Root password set successfully"* ]
}

@test "Test new user creation" {
    run create_new_user "testuser" "testpassword"
    [ "$status" -eq 0 ]
    [ "$output" = *"User 'testuser' created successfully"* ]
}

@test "Test additional package installation" {
    # Mock the prompt_additional_packages function
    prompt_additional_packages() {
        echo "vim git"
    }
    run install_additional_packages
    [ "$status" -eq 0 ]
    [ "$output" = *"Packages installed successfully"* ]
}
