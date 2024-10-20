#!/bin/bash

# Define tool name, version, and custom colors
TOOL_NAME="PXE-TOOL"
VERSION="1.0"
CREATOR="Kumar"

# Define color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Display the custom heading
echo -e "${GREEN}${TOOL_NAME}${NC} - ${BLUE}Version ${VERSION}${NC} ${YELLOW}Created by ${CREATOR}${NC}"

# Function to install required packages
install_services() {
    echo "Installing required services..."
    sudo apt update
    sudo apt install -y dnsmasq tftpd-hpa syslinux nfs-kernel-server apache2 wget
    echo "Services installed."
}

# Function to configure network
configure_network() {
    read -p "Enter the network interface (e.g., eth0): " NET_INTERFACE
    read -p "Enter the network name: " NETWORK_NAME
    read -p "Enter the IP range (e.g., 192.168.1.100,192.168.1.200): " IP_RANGE
    
    echo "Updating network configuration..."
    sudo cat > /etc/dnsmasq.conf <<EOL
interface=$NET_INTERFACE
dhcp-range=$IP_RANGE
EOL

    echo "Network configuration updated."
}

# Function to configure PXE boot for TFTP
configure_pxe_tftp() {
    read -p "Enter the OS filename (placed in the PXE tool folder): " OS_FILE
    PXE_PATH="/srv/tftp"

    if [ ! -f "./$OS_FILE" ]; then
        echo "OS file not found in PXE tool folder!"
        exit 1
    fi

    echo "Copying OS file to TFTP root..."
    sudo cp ./$OS_FILE $PXE_PATH

    # Generate pxelinux.cfg for TFTP
    sudo mkdir -p $PXE_PATH/pxelinux.cfg
    sudo cat > $PXE_PATH/pxelinux.cfg/default <<EOL
DEFAULT linux
LABEL linux
  KERNEL vmlinuz
  APPEND initrd=initrd.img root=/dev/nfs rw
EOL

    echo "PXE configuration for TFTP complete."
}

# Function to configure PXE boot for NFS
configure_pxe_nfs() {
    read -p "Enter the OS directory (placed in the PXE tool folder): " OS_DIR
    NFS_PATH="/srv/nfs"

    if [ ! -d "./$OS_DIR" ]; then
        echo "OS directory not found in PXE tool folder!"
        exit 1
    fi

    echo "Copying OS files to NFS root..."
    sudo mkdir -p $NFS_PATH
    sudo cp -r ./$OS_DIR $NFS_PATH

    # Configure NFS export
    sudo bash -c "echo '$NFS_PATH *(rw,sync,no_root_squash)' >> /etc/exports"
    sudo exportfs -ra

    # Generate pxelinux.cfg for NFS
    sudo mkdir -p /srv/tftp/pxelinux.cfg
    sudo cat > /srv/tftp/pxelinux.cfg/default <<EOL
DEFAULT linux
LABEL linux
  KERNEL vmlinuz
  APPEND initrd=initrd.img root=/dev/nfs nfsroot=$NFS_PATH rw ip=dhcp
EOL

    echo "PXE configuration for NFS complete."
}

# Function to configure PXE boot for HTTP
configure_pxe_http() {
    read -p "Enter the OS filename (placed in the PXE tool folder): " OS_FILE
    HTTP_PATH="/var/www/html/pxe"

    if [ ! -f "./$OS_FILE" ]; then
        echo "OS file not found in PXE tool folder!"
        exit 1
    fi

    echo "Copying OS file to Apache HTTP root..."
    sudo mkdir -p $HTTP_PATH
    sudo cp ./$OS_FILE $HTTP_PATH

    # Ensure Apache is running
    sudo systemctl enable apache2
    sudo systemctl restart apache2

    # Generate pxelinux.cfg for HTTP
    sudo mkdir -p /srv/tftp/pxelinux.cfg
    sudo cat > /srv/tftp/pxelinux.cfg/default <<EOL
DEFAULT linux
LABEL linux
  KERNEL http://$HOSTNAME/pxe/vmlinuz
  APPEND initrd=http://$HOSTNAME/pxe/initrd.img root=/dev/nfs rw
EOL

    echo "PXE configuration for HTTP complete."
}

# Function to start services
start_services() {
    echo "Starting services..."
    sudo systemctl restart dnsmasq tftpd-hpa nfs-kernel-server apache2
    echo "Services started."
}

# Function to choose the boot method
choose_boot_method() {
    echo "Choose the boot method:"
    echo "1) TFTP"
    echo "2) NFS"
    echo "3) HTTP"
    read -p "Enter choice [1-3]: " BOOT_METHOD

    case $BOOT_METHOD in
        1)
            configure_pxe_tftp
            ;;
        2)
            configure_pxe_nfs
            ;;
        3)
            configure_pxe_http
            ;;
        *)
            echo "Invalid choice, exiting..."
            exit 1
            ;;
    esac
}

# Check if services are installed, else install
install_services

# Configure network
configure_network

# Choose and configure boot method
choose_boot_method

# Start PXE services
start_services

echo "PXE environment is ready and services are running."
