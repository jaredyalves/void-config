#!/bin/bash

# List available disks
lsblk -d -o NAME,SIZE | awk 'NR > 1 {print NR-1 ". " $1 " (" $2 ")"}'

# Prompt for disk selection
read -p "Enter the number of the disk: " disk_number

# Get the selected disk device
selected_disk=$(lsblk -d -o NAME | awk 'NR > 1' | awk "NR == $disk_number")

# Check if the disk is NVMe
if [[ $selected_disk == *"nvme"* ]]; then
    selected_disk=${selected_disk}p
fi

# Select mirror and architecture
REPO=https://repo-default.voidlinux.org/current
ARCH=x86_64

# Copy RSA keys
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

# Bootstrap the installation using XBPS method
XBPS_ARCH=$ARCH xbps-install -Sy -r /mnt -R "$REPO" ansible base-system git grub-x86_64-efi

# Set hostname
read -p "Enter the hostname: " hostname
echo "$hostname" > /mnt/etc/hostname

# Set root password
echo "Setting the root password..."
xchroot /mnt /bin/passwd

# Create user
echo "Creating the user..."
xchroot /mnt /bin/bash << EOF
useradd -mG wheel user
EOF
echo "Setting the user password..."
xchroot /mnt /bin/passwd user

# Add the 'wheel' group to the sudoers file
echo "%wheel ALL=(ALL) ALL" > /mnt/etc/sudoers.d/wheel_group

# Generate locale files
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/default/libc-locales
xchroot /mnt /bin/bash << EOF
xbps-reconfigure -f glibc-locales
EOF

# Configure fstab
UEFI_UUID="UUID=$(blkid -s UUID -o value /dev/${selected_disk}1)"
ROOT_UUID="UUID=$(blkid -s UUID -o value /dev/${selected_disk}2)"
cat << EOF > /mnt/etc/fstab
# <file system> <dir> <type> <options> <dump> <pass>
$UEFI_UUID  /boot/efi   vfat    defaults    0 0
$ROOT_UUID  /           ext4    defaults    0 0
tmpfs   /tmp    tmpfs   defaults,nosuid,nodev   0 0
EOF

# Install GRUB
xchroot /mnt /bin/bash << EOF
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void"
EOF

# Generate UEFI fallback
mkdir -p /mnt/boot/efi/EFI/boot
cp /mnt/boot/efi/EFI/Void/grubx64.efi /mnt/boot/efi/EFI/boot/bootx64.efi

# Reconfigure
xchroot /mnt /bin/bash << EOF
xbps-reconfigure -fa
EOF

echo "Installation complete. You may now reboot."
