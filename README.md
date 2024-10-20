PXE-Tool is a simple and customizable script to set up a PXE (Preboot Execution Environment) server on Linux. It allows users to boot operating systems over the network using TFTP, NFS, or HTTP.

Features

	•	Automatic Configuration: Set up PXE services (DHCP, TFTP, NFS, HTTP) automatically based on user input.
	•	Boot Methods: Supports TFTP, NFS, and HTTP boot methods.
	•	Dynamic Resource Download: Installs required packages and services automatically during execution.
	•	Customization: Prompts for network configurations such as interface, DHCP range, and boot file or directory.

Requirements

	•	Linux (Tested on Ubuntu/Debian)
	•	Git must be installed (sudo apt install git)
	•	Root (sudo) access

Installation

To install the PXE-Tool, follow these steps:

	1.	Clone the repository:
 git clone https://github.com/kumarraju2108/PXE-TOOL.git

 2.	Make the script executable:
    chmod +x pxe-tool.sh

How to Run the PXE-Tool

	1.	Run the tool with root (sudo):
 sudo ./pxe-tool.sh

 2.	Follow the prompts:
	•	Network Interface: Enter the network interface (e.g., eth0).
	•	DHCP IP Range: Enter the IP range for PXE clients (e.g., 192.168.1.100,192.168.1.200).
	•	Boot Method: Choose from TFTP, NFS, or HTTP.
	•	OS File: Provide the OS file or directory that clients will boot from.
	3.	Wait for the PXE environment to configure:
	•	The script will automatically install and start the required services (DHCP, TFTP, NFS, HTTP).
	4.	Start PXE Boot:
	•	Configure a PXE client (virtual machine or physical machine) to boot from the network.
	•	The client should receive the necessary boot files and start the OS installation process.

Example Use Case (Testing in Oracle VirtualBox)

For testing:

	•	Set up one VM as the PXE server and another as the PXE client.
	•	Both VMs should be on the same network (e.g., via Bridged or Host-Only Adapter).
	•	The PXE client will boot through the network and download the OS provided by the server.

Troubleshooting

	1.	DHCP IP Issues: Ensure the network interface is correct and not conflicting with other DHCP servers on the network.
	2.	PXE Client Not Booting: Verify that the client VM is configured to boot from the network.
	3.	Service Issues: If TFTP, NFS, or HTTP services are not starting, check the logs (journalctl -xe or systemctl status [service-name]).

Contributing

If you’d like to contribute to this project, feel free to fork the repository and submit a pull request. All contributions are welcome!

NOTE:-When installing an operating system via PXE (Preboot Execution Environment), it is essential to download the necessary files directly into the designated folder for PXE. This ensures that all required components are organized and readily accessible during the installation process. Properly structuring your file management in this manner will facilitate a smoother installation experience and minimize potential errors.
