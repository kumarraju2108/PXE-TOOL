#!/bin/bash

# Function to install required packages
install_packages() {
    echo "Updating and installing packages..."
    if ! sudo apt update; then
        echo "Failed to update package list."
        exit 1
    fi
    if ! sudo apt install -y dnsmasq tftpd-hpa syslinux-common shim-signed grub-efi-amd64-signed grub-common; then
        echo "Failed to install required packages."
        exit 1
    fi
}

# Function to configure UFW to allow necessary ports
configure_firewall() {
    echo "Configuring firewall..."

    # Allow necessary ports for dnsmasq and tftp
    sudo ufw allow 1053/tcp  # DNS port for dnsmasq
    sudo ufw allow 1053/udp  # DNS port for dnsmasq
    sudo ufw allow 69/udp     # TFTP port

    # Enable UFW if it's not already enabled
    if ! sudo ufw status | grep -q "Status: active"; then
        echo "Enabling UFW..."
        sudo ufw enable
    fi

    echo "Firewall configured."
}

# Function to configure dnsmasq
configure_dnsmasq() {
    echo "Configuring dnsmasq..."

    # Prompt for network interface and validate
    while true; do
        read -p "Enter network interface (e.g., eth0): " interface
        if ip link show "$interface" &> /dev/null; then
            break
        else
            echo "Invalid interface name. Please try again."
        fi
    done

    # Prompt for IP range and validate
    while true; do
        read -p "Enter PXE IP range start (e.g., 192.168.0.100): " ip_start
        read -p "Enter PXE IP range end (e.g., 192.168.0.200): " ip_end

        # Validate IP addresses
        if [[ "$ip_start" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ "$ip_end" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        else
            echo "Invalid IP address format. Please try again."
        fi
    done

    # Backup existing dnsmasq configuration
    sudo cp /etc/dnsmasq.conf.d/pxe.conf /etc/dnsmasq.conf.d/pxe.conf.bak 2>/dev/null

    cat <<EOF | sudo tee /etc/dnsmasq.conf.d/pxe.conf
interface=${interface},lo
bind-interfaces
port=1053  # Change DNS port
dhcp-range=${ip_start},${ip_end}
dhcp-boot=pxelinux.0
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-boot=tag:efi-x86_64,bootx64.efi
enable-tftp
tftp-root=/srv/tftp
EOF

    if ! sudo systemctl restart dnsmasq.service; then
        echo "Failed to restart dnsmasq service."
        exit 1
    fi
    echo "dnsmasq configured and restarted."
}

# Function to download PXE boot files
download_pxe_files() {
    echo "Downloading necessary PXE files..."

    sudo mkdir -p /srv/tftp/boot-amd64 /srv/tftp/pxelinux.cfg

    # Attempt to download pxelinux.0
    if ! wget -q http://archive.ubuntu.com/ubuntu/dists/focal/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64/pxelinux.0 -O /srv/tftp/pxelinux.0; then
        echo "Failed to download pxelinux.0. Attempting to copy from local syslinux installation."
        if [ -f /usr/lib/syslinux/pxelinux.0 ]; then
            sudo cp /usr/lib/syslinux/pxelinux.0 /srv/tftp/
        else
            echo "Local pxelinux.0 not found. Please check syslinux installation."
            exit 1
        fi
    fi

    sudo cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /srv/tftp/

    if ! apt download grub-common && dpkg-deb --fsys-tarfile grub-common*.deb | sudo tar x ./usr/share/grub/unicode.pf2 -O > /srv/tftp/unicode.pf2; then
        echo "Failed to extract unicode.pf2."
        exit 1
    fi

    echo "PXE files downloaded."
}

# Function to configure GRUB
configure_grub() {
    echo "Configuring GRUB for PXE..."

    read -p "Do you want to include an OS ISO download URL? (y/n): " include_url

    sudo mkdir -p /srv/tftp/grub

    if [ "$include_url" == "y" ]; then
        read -p "Enter the OS ISO download URL: " os_url

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
    configure_firewall
    configure_dnsmasq
    download_pxe_files
    configure_grub
    echo "PXE server setup completed successfully."
}

main
