#!/bin/bash

# List available disks
lsblk -d -o NAME,SIZE | awk 'NR > 1 {print NR-1 ". " $1 " (" $2 ")"}'

# Prompt for disk selection
read -p "Enter the number of the disk: " disk_number

# Get the selected disk device
selected_disk=$(lsblk -d -o NAME | awk 'NR > 1' | awk "NR == $disk_number")

# Check if parted is installed
if ! command -v parted &> /dev/null; then
    echo "parted is not installed. Installing..."
    xbps-install -Sy parted
fi

# Partition disk
echo "Partitioning the disk..."
parted --script /dev/$selected_disk mklabel gpt
parted --script /dev/$selected_disk mkpart primary 1MiB 512MiB
parted --script /dev/$selected_disk set 1 esp on
parted --script /dev/$selected_disk mkpart primary 512MiB 100%

# Check if the disk is NVMe
if [[ $selected_disk == *"nvme"* ]]; then
    selected_disk=${selected_disk}p
fi

# Format partitions
echo "Formatting the partitions..."
mkfs.fat -F32 /dev/${selected_disk}1
mkfs.ext4 -F /dev/${selected_disk}2

# Mount partitions
echo "Mounting the partitions..."
mount /dev/${selected_disk}2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/${selected_disk}1 /mnt/boot/efi

# Run the install script
./install.sh
