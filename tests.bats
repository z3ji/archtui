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
