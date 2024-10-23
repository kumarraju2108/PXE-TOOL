PXE Server Setup Script
This script sets up a PXE (Preboot Execution Environment) server on an Ubuntu system, allowing you to boot client machines over the network and install Ubuntu OS directly from an ISO file.

Overview
The script performs the following tasks:

Prompts for network configuration details.
Checks for port conflicts.
Installs necessary packages (DHCP, TFTP, NFS, etc.).
Configures the DHCP server to allocate IP addresses to clients.
Sets up the TFTP server to serve boot files.
Mounts the specified Ubuntu ISO for installation.
Configures NFS to share the installer files.
Sets up a PXE boot menu for client machines.
Prerequisites
Ubuntu Server or Desktop installed.
Internet access to install packages.
Administrative (sudo) privileges.
Usage Instructions
Download the Script: Clone or download this repository and navigate to the script directory.

bash
Copy code
git clone <repository-url>
cd <repository-directory>
Make the Script Executable: Run the following command to make the script executable:

bash
Copy code
chmod +x pxe_setup.sh
Run the Script: Execute the script with the following command:

bash
Copy code
sudo ./pxe_setup.sh
Follow Prompts: The script will prompt you for various configuration details. Enter the required values, or press Enter to accept the defaults.

Configuration Prompts
PXE Server IP: The IP address of the PXE server.
Subnet: The subnet used by your network (e.g., 192.168.1.0).
Subnet Mask: The subnet mask (default is usually 255.255.255.0).
DHCP Range: The range of IP addresses to be allocated to clients.
Router IP: The gateway/router IP address.
DNS Server IP: DNS server IP (usually the same as the router IP).
Ubuntu ISO File Name: The name of the Ubuntu ISO located in your ~/Downloads folder (e.g., ubuntu-22.04-live-server-amd64.iso).
How It Works
DHCP Server: Configured to provide IP addresses to network clients.
TFTP Server: Serves boot files over the network, allowing clients to boot from the PXE server.
NFS Server: Shares the mounted Ubuntu installer files for client installations.
Error Handling and Troubleshooting
Port Conflicts:

If you see an error indicating that ports 67 (DHCP), 69 (TFTP), or 2049 (NFS) are in use, stop the services using those ports.
Use sudo lsof -i :<port> to find out which service is using the port and stop it with sudo systemctl stop <service-name>.
File Not Found:

Ensure that the Ubuntu ISO file name is correct and that it is located in your ~/Downloads directory.
Permission Denied:

If you encounter permission errors, ensure you are running the script with sudo.
Service Fails to Start:

Check the status of services with:
bash
Copy code
sudo systemctl status <service-name>
Review logs for more details:
bash
Copy code
journalctl -xe
Networking Issues:

Ensure that your network configuration (IP addresses, subnet) is correctly set up.
Final Notes
After the script completes, you can boot client machines from the network and start the Ubuntu installation.
Make sure client machines are set to boot from the network in BIOS/UEFI settings.
License
This script is licensed under the MIT License. See the LICENSE file for more details.

Feel free to modify any sections as needed! This README should provide users with a clear understanding of how to use your PXE server setup script effectively.
