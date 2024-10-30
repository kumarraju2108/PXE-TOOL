#!/bin/bash

# Function to install required packages
install_packages() {
    echo "Updating and installing packages..."
    sudo apt update
    sudo apt install -y dnsmasq tftpd-hpa syslinux-common shim-signed grub-efi-amd64-signed grub-common
}

# Function to configure dnsmasq
configure_dnsmasq() {
    echo "Configuring dnsmasq..."

    # Prompt for interface and IP range
    read -p "Enter network interface (e.g., eth0): " interface
    read -p "Enter PXE IP range start (e.g., 192.168.0.100): " ip_start
    read -p "Enter PXE IP range end (e.g., 192.168.0.200): " ip_end

    # Configure dnsmasq for PXE booting
    cat <<EOF | sudo tee /etc/dnsmasq.conf.d/pxe.conf
interface=${interface},lo
bind-interfaces
dhcp-range=${interface},${ip_start},${ip_end}
dhcp-boot=pxelinux.0
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-boot=tag:efi-x86_64,bootx64.efi
enable-tftp
tftp-root=/srv/tftp
EOF

    # Restart dnsmasq service
    sudo systemctl restart dnsmasq.service
    echo "dnsmasq configured and restarted."
}

# Function to download PXE boot files
download_pxe_files() {
    echo "Downloading necessary PXE files..."

    # Create necessary directories
    sudo mkdir -p /srv/tftp/boot-amd64 /srv/tftp/pxelinux.cfg

    # Download PXE bootloader and GRUB font
    sudo wget -q http://archive.ubuntu.com/ubuntu/dists/focal/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64/pxelinux.0 -O /srv/tftp/pxelinux.0
    sudo cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /srv/tftp/
    apt download grub-common && dpkg-deb --fsys-tarfile grub-common*.deb | sudo tar x ./usr/share/grub/unicode.pf2 -O > /srv/tftp/unicode.pf2

    echo "PXE files downloaded."
}

# Function to configure GRUB with or without OS URL
configure_grub() {
    echo "Configuring GRUB for PXE..."

    # Ask if OS URL should be included for automatic download
    read -p "Do you want to include an OS ISO download URL? (y/n): " include_url

    if [ "$include_url" == "y" ]; then
        read -p "Enter the OS ISO download URL (e.g., http://cdimage.ubuntu.com/ubuntu/releases/20.04.5/release/ubuntu-20.04.5-live-server-amd64.iso): " os_url

        # Create GRUB config with OS download URL
        cat <<EOF | sudo tee /srv/tftp/grub/grub.cfg
set default="0"
set timeout=-1

if loadfont unicode ; then
  set gfxmode=auto
  set locale_dir=\$prefix/locale
  set lang=en_US
fi

terminal_output gfxterm
set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Install OS from Network" {
  set gfxpayload=keep
  linux /casper/vmlinuz url=$os_url ip=dhcp ---
  initrd /casper/initrd
}
EOF

        echo "GRUB configured with OS download URL."
    else
        # Create GRUB config without OS download URL
        cat <<EOF | sudo tee /srv/tftp/grub/grub.cfg
set default="0"
set timeout=-1

if loadfont unicode ; then
  set gfxmode=auto
  set locale_dir=\$prefix/locale
  set lang=en_US
fi

terminal_output gfxterm
set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry 'Ubuntu PXE Boot' {
  linux /casper/vmlinuz quiet splash
  initrd /casper/initrd
}
EOF

        echo "GRUB configured without OS download URL."
    fi
}

# Main function
main() {
    install_packages
    configure_dnsmasq
    download_pxe_files
    configure_grub
    echo "PXE server setup completed successfully."
}

main
