# ArchTUI

This Bash script provides a Terminal User Interface (TUI) for installing my Arch Linux install.

## Features

- **Partition Disk:** Partition the disk with options for ext4 or Btrfs (timeshift) filesystems.
- **Install Base System:** Install the base Arch Linux system with minimal or desktop environment options (GNOME or KDE).
- **Configure System:** Set hostname, network settings, root password, create a new user, and add sudo privileges.
- **Install Additional Packages:** Install additional packages via Pacman.

## Prerequisites

- Boot into the [Arch Linux](https://archlinux.org/download/) live ISO.
- Ensure you have a working internet connection.
- Run the script as root or using sudo.

## Usage

1. Clone the repository: ```git clone https://github.com/z3ji/archtui```
2. Make the script executable: `chmod +x arch_install.sh`
3. Run the script: `./arch_install.sh`

Follow the on-screen prompts to proceed with the installation.
