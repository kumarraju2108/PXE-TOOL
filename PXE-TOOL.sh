#!/bin/bash

# Function to prompt for user input with default value
prompt() {
  read -p "$1 [$2]: " input
  echo "${input:-$2}"
}

# Function to check if a port is in use and stop the service if it is
check_and_stop_service() {
  local port=$1
  local service=$2
  if sudo lsof -i :$port > /dev/null; then
    echo "Port $port is already in use by the $service service."
    echo "Stopping the $service service..."
    sudo systemctl stop "$service"
  fi
}

# Function to set up Ubuntu OS from the specified ISO
setup_ubuntu() {
  local iso_file=$1
  os_name="Ubuntu"
  kernel_path="ubuntu-installer/casper/vmlinuz"
  initrd_path="ubuntu-installer/casper/initrd"

  echo "Using local ISO at ~/Downloads/$iso_file..."
  sudo mkdir -p /var/lib/tftpboot/$os_name-installer
  sudo mount -o loop ~/Downloads/"$iso_file" /var/lib/tftpboot/$os_name-installer
}

# Function to wait for client installation to complete
wait_for_client_installation() {
  local client_ip=$1
  local timeout=600  # Timeout in seconds
  local interval=10   # Check every 10 seconds
  local elapsed=0

  echo "Waiting for client installation to complete..."

  while [[ $elapsed -lt $timeout ]]; do
    if ping -c 1 "$client_ip" &> /dev/null; then
      echo "Client is reachable. Checking installation status..."
      # Here you could add more checks specific to your installation process.
      # For example, checking for a specific service, log file, or state.
      break
    fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done

  if [[ $elapsed -ge $timeout ]]; then
    echo "Timeout: Client installation did not complete within $timeout seconds."
  else
    echo "Client installation is ongoing."
  fi
}

# Ask for the network interface name
dhcp_interface=$(prompt "Enter the network interface name (e.g., ens33)" "ens33")

# Get the IP address and subnet mask of the specified interface
ip_address=$(ip -o -f inet addr show "$dhcp_interface" | awk '{print $4}')
subnet_mask=$(ip -o -f inet addr show "$dhcp_interface" | awk '{print $2}')

# Check if the specified interface exists and has an IP
if [[ -z "$ip_address" ]]; then
  echo "Error: Network interface '$dhcp_interface' does not have an IP address assigned."
  exit 1
fi

# Default values for DHCP
pxe_server_ip=$ip_address
subnet="${ip_address%.*}.0" # Assuming /24 for the subnet
dhcp_range_start="${subnet%.*}.100"
dhcp_range_end="${subnet%.*}.200"
router_ip=$ip_address
dns_server_ip=$ip_address

echo "PXE Server Setup Script"

# Ask for the Ubuntu ISO file name
read -p "Enter the name of the Ubuntu ISO file in the Downloads folder (e.g., ubuntu-22.04-live-server-amd64.iso): " iso_file

# Check for and stop services if they are using the required ports
echo "Checking for port conflicts..."
check_and_stop_service 67    "isc-dhcp-server"  # DHCP uses port 67
check_and_stop_service 69    "tftpd-hpa"        # TFTP uses port 69
check_and_stop_service 2049  "nfs-kernel-server" # NFS uses port 2049

# Update system and install required packages
echo "Updating system and installing required packages..."
sudo apt update
sudo apt install -y isc-dhcp-server tftpd-hpa tftp-hpa nfs-kernel-server syslinux wget

# Configure DHCP server
echo "Configuring DHCP server..."
sudo tee /etc/dhcp/dhcpd.conf > /dev/null <<EOL
subnet $subnet netmask $subnet_mask {
  range $dhcp_range_start $dhcp_range_end;
  option routers $router_ip;
  option domain-name-servers $dns_server_ip;
  option subnet-mask $subnet_mask;
  option broadcast-address ${subnet%.*}.255;
  next-server $pxe_server_ip;
  filename "pxelinux.0";
}
EOL

# Specify the DHCP interface
sudo sed -i "s/INTERFACESv4=\"\"/INTERFACESv4=\"$dhcp_interface\"/" /etc/default/isc-dhcp-server

# Restart DHCP server
echo "Restarting DHCP server..."
sudo systemctl restart isc-dhcp-server

# Configure TFTP server
echo "Configuring TFTP server..."
sudo tee /etc/default/tftpd-hpa > /dev/null <<EOL
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/var/lib/tftpboot"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="--secure"
EOL

# Create PXE boot directory and copy necessary files
echo "Setting up PXE boot environment..."
sudo mkdir -p /var/lib/tftpboot/pxelinux.cfg
sudo cp /usr/lib/syslinux/pxelinux.0 /var/lib/tftpboot/
sudo cp /usr/lib/syslinux/ldlinux.c32 /var/lib/tftpboot/
sudo cp /usr/lib/syslinux/menu.c32 /var/lib/tftpboot/
sudo cp /usr/lib/syslinux/mboot.c32 /var/lib/tftpboot/

# Restart TFTP service
echo "Restarting TFTP server..."
sudo systemctl restart tftpd-hpa

# Set up Ubuntu OS
setup_ubuntu "$iso_file"

# Configure NFS to share the installer
echo "Configuring NFS..."
sudo tee -a /etc/exports > /dev/null <<EOL
/var/lib/tftpboot/$os_name-installer $subnet/24(ro,sync,no_root_squash,no_subtree_check)
EOL
sudo exportfs -a
sudo systemctl restart nfs-kernel-server

# Configure PXE boot menu
echo "Configuring PXE boot menu..."
sudo tee /var/lib/tftpboot/pxelinux.cfg/default > /dev/null <<EOL
DEFAULT install
LABEL install
  MENU LABEL Install $os_name
  KERNEL $os_name-installer/$kernel_path
  APPEND initrd=$os_name-installer/$initrd_path -- boot=casper netboot=nfs nfsroot=$pxe_server_ip:/var/lib/tftpboot/$os_name-installer
EOL

# Ask for client IP address to monitor
client_ip=$(prompt "Enter the client IP address to monitor during installation" "$dhcp_range_start")

# Wait for client installation to complete
wait_for_client_installation "$client_ip"

# Final instructions
echo "PXE server setup complete!"
echo "You can now boot your client nodes from the network and start the $os_name OS installation."
