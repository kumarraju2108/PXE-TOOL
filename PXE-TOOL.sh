#!/bin/bash

# Function to prompt for user input with default value
prompt() {
  read -p "$1 [$2]: " input
  echo "${input:-$2}"
}

# Function to check if a port is in use
check_port_in_use() {
  local port=$1
  if sudo lsof -i :$port > /dev/null; then
    echo "Warning: Port $port is already in use. Continuing if it's the required service."
    return 1
  fi
  return 0
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

# Default values
pxe_server_ip="192.168.1.10"
subnet="192.168.1.0"
subnet_mask="255.255.255.0"
dhcp_range_start="192.168.1.100"
dhcp_range_end="192.168.1.200"
router_ip="192.168.1.1"
dns_server_ip="192.168.1.1"

echo "PXE Server Setup Script"

# Ask for the network interface name
dhcp_interface=$(prompt "Enter the network interface name (e.g., eth0)" "eth0")

# Check if the specified interface exists
if ! ip link show "$dhcp_interface" > /dev/null; then
  echo "Error: Network interface '$dhcp_interface' does not exist."
  exit 1
fi

# Ask for the Ubuntu ISO file name
read -p "Enter the name of the Ubuntu ISO file in the Downloads folder (e.g., ubuntu-22.04-live-server-amd64.iso): " iso_file

# Check for port conflicts
echo "Checking for port conflicts..."
check_port_in_use 67    # DHCP uses port 67
check_port_in_use 69    # TFTP uses port 69
check_port_in_use 2049  # NFS uses port 2049

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

# Create client-side IP check script
client_script_path="/var/lib/tftpboot/ip_check.sh"
sudo tee "$client_script_path" > /dev/null <<'EOL'
#!/bin/bash

# Check if an IP address is assigned
ip_address=$(hostname -I | awk '{print $1}')

if [[ -z "$ip_address" ]]; then
  echo "No IP address assigned."
else
  echo "IP address assigned: $ip_address"
  echo "Node details:"
  echo "Hostname: $(hostname)"
  echo "MAC Address: $(cat /sys/class/net/$(ip -o -f inet link show | awk '{print $2}')/address)"
fi
EOL

# Make the client script executable
sudo chmod +x "$client_script_path"

# Final instructions
echo "PXE server setup complete!"
echo "You can now boot your client nodes from the network and start the $os_name OS installation."
echo "To check the assigned IP address and node details, use the script at $client_script_path on the client machine."

