#!/bin/bash

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null; then
        echo "Port $port is already in use. Exiting."
        exit 1
    fi
}

# Check if necessary ports are available
check_port 67  # DHCP
check_port 69  # TFTP

# Choose a different port for TFTP
tftp_port=7777
check_port $tftp_port

# Prompt for user input
read -p "Enter the network interface name (e.g., ens33): " interface
read -p "Enter the server IP address (e.g., 172.17.199.199): " server_ip
read -p "Enter the name of the ISO file to be saved (without extension): " iso_name

# Define DHCP configuration
dhcp_conf="/etc/dhcp/dhcpd.conf"
tftp_conf="/etc/default/tftpd-hpa"

# Backup existing configuration files
sudo cp $dhcp_conf ${dhcp_conf}.bak
sudo cp $tftp_conf ${tftp_conf}.bak

# Generate DHCP configuration
cat <<EOL | sudo tee $dhcp_conf
subnet 172.17.0.0 netmask 255.255.0.0 {
    range 172.17.199.200 172.17.199.250;
    option domain-name-servers $server_ip, 8.8.8.8;
    option subnet-mask 255.255.0.0;
    option routers $server_ip;
    option broadcast-address 172.17.255.255;
    option ntp-servers 0.0.0.0;
    next-server $server_ip;
    filename "pxelinux.0";
}
EOL

# Generate TFTP configuration
cat <<EOL | sudo tee $tftp_conf
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/var/lib/tftpboot"
TFTP_ADDRESS="0.0.0.0:$tftp_port"
TFTP_OPTIONS="--secure"
EOL

# Create TFTP boot directory
sudo mkdir -p /var/lib/tftpboot
sudo cp /usr/lib/syslinux/pxelinux.0 /var/lib/tftpboot/
sudo cp /usr/lib/syslinux/ldlinux.c32 /var/lib/tftpboot/
sudo mkdir -p /var/lib/tftpboot/pxelinux.cfg
sudo touch /var/lib/tftpboot/pxelinux.cfg/default

# Create PXE configuration file
cat <<EOL | sudo tee /var/lib/tftpboot/pxelinux.cfg/default
DEFAULT menu.c32
PROMPT 0
TIMEOUT 300

LABEL linux
    KERNEL ubuntu-installer/amd64/linux
    APPEND initrd=ubuntu-installer/amd64/initrd.gz
EOL

# Set up NFS (if needed)
if [[ ! -d /var/nfs ]]; then
    sudo mkdir -p /var/nfs
    echo "/var/nfs 172.17.0.0/24(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
    sudo exportfs -a
fi

# Start and enable services
sudo systemctl restart isc-dhcp-server
sudo systemctl enable isc-dhcp-server
sudo systemctl restart tftpd-hpa
sudo systemctl enable tftpd-hpa
sudo systemctl restart nfs-kernel-server
sudo systemctl enable nfs-kernel-server

# Firewall configuration
sudo ufw allow 67/udp  # Allow DHCP
sudo ufw allow $tftp_port/udp  # Allow TFTP on custom port

echo "PXE server setup complete. ISO file '$iso_name' should be saved in the directory specified."
