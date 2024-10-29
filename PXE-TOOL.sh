#!/bin/bash

# Define the local OS images directory within the PXE folder structure
local_images_dir="/var/lib/tftpboot/local-os-images"

# Prompt for interface name and IP address
read -p "Enter the network interface name (e.g., eth0): " interface
read -p "Enter the IP address of the PXE server (e.g., 192.168.1.100): " server_ip

# Function to check and install required services
install_required_services() {
    echo "Checking required services..."
    for service in dnsmasq tftp-server httpd; do
        if ! rpm -q $service; then
            echo "Installing $service..."
            sudo yum install -y $service
        fi
        sudo systemctl enable $service
        sudo systemctl start $service
    done
}

# Function to check and resolve port conflicts
check_port_conflicts() {
    ports=(69 80)
    for port in "${ports[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null; then
            echo "Port $port is in use. Attempting to find an alternative."
            new_port=$((port + 1))
            while lsof -Pi :$new_port -sTCP:LISTEN -t >/dev/null; do
                new_port=$((new_port + 1))
            done
            echo "Port $port is busy. Assigning new port $new_port."
            # Adjust dnsmasq and httpd configurations
            if [ "$port" -eq 80 ]; then
                sudo sed -i "s/^Listen 80$/Listen $new_port/" /etc/httpd/conf/httpd.conf
            elif [ "$port" -eq 69 ]; then
                sudo sed -i "s/^tftp-port=69$/tftp-port=$new_port/" /etc/dnsmasq.conf
            fi
        fi
    done
}

# Function to process OS ISO
process_os_iso() {
    os_file=$1
    os_name=$(basename "$os_file" .iso)
    dest_dir="$local_images_dir/$os_name"

    # Check if the directory already exists
    if [[ -d $dest_dir ]]; then
        echo "Directory $dest_dir already exists. Please remove or rename it before adding a new OS."
        exit 1
    fi

    # Create directory for OS if it doesn't exist
    mkdir -p "$dest_dir"

    # Copy the OS ISO to the designated directory
    echo "Copying $os_file to $dest_dir..."
    cp "$os_file" "$dest_dir/$os_name.iso"
}

# Function to process new OS version ISO
process_os_version() {
    os_file=$1
    os_name=$(basename "$os_file" .iso | cut -d '-' -f1)
    os_version=$(basename "$os_file" .iso | cut -d '-' -f2)
    dest_dir="$local_images_dir/$os_name/$os_version"

    # Check if the OS base directory exists
    if [[ ! -d "$local_images_dir/$os_name" ]]; then
        echo "Base directory for $os_name does not exist. Please add the base OS first."
        exit 1
    fi

    # Create directory for OS version if it doesn't exist
    mkdir -p "$dest_dir"

    # Copy the OS version ISO to the designated directory
    echo "Copying $os_file to $dest_dir..."
    cp "$os_file" "$dest_dir/${os_name}_${os_version}.iso"
}

# Function to generate the iPXE boot configuration
generate_ipxe_config() {
    ipxe_file="/var/lib/tftpboot/boot.ipxe"
    echo "#!ipxe" | sudo tee "$ipxe_file"
    echo "set server_ip ${server_ip}" | sudo tee -a "$ipxe_file"
    echo "set root_path http://\${server_ip}/os-images" | sudo tee -a "$ipxe_file"

    # Add boot menu entries dynamically for each OS and version
    for os_dir in "$local_images_dir"/*; do
        os_name=$(basename "$os_dir")
        for version_dir in "$os_dir"/*; do
            if [[ -d $version_dir ]]; then
                os_version=$(basename "$version_dir")
                echo "menuentry ${os_name} ${os_version}" | sudo tee -a "$ipxe_file"
                echo "kernel \${root_path}/${os_name}/${os_version}/vmlinuz" | sudo tee -a "$ipxe_file"
                echo "initrd \${root_path}/${os_name}/${os_version}/initrd.img" | sudo tee -a "$ipxe_file"
                echo "boot" | sudo tee -a "$ipxe_file"
                echo " " | sudo tee -a "$ipxe_file"
            fi
        done
    done
}

# Accept OS ISO or OS version ISO as an argument with -o or -n option
while getopts "o:n:" opt; do
    case "$opt" in
        o) os_file=$OPTARG
           process_os_iso "$os_file"
           ;;
        n) os_file=$OPTARG
           process_os_version "$os_file"
           ;;
        *) echo "Usage: $0 -o <osfilename.iso> for new OS or -n <osfilename-version.iso> for new version"; exit 1 ;;
    esac
done

# Create the local images directory if it doesn't exist
mkdir -p "$local_images_dir"

# Execute functions
install_required_services
check_port_conflicts

# Create dnsmasq configuration for PXE
cat <<EOF | sudo tee /etc/dnsmasq.d/pxe.conf
interface=$interface
dhcp-range=$server_ip,proxy
dhcp-boot=boot.ipxe
enable-tftp
tftp-root=/var/lib/tftpboot
EOF

# Link OS directory to HTTP server
sudo ln -sf "$local_images_dir" /var/www/html/os-images
sudo systemctl restart dnsmasq
sudo systemctl restart httpd

# Generate the iPXE boot configuration
generate_ipxe_config

echo "PXE server is configured. You can add more OS or OS versions with:"
echo "  $0 -o <osfilename.iso> for a new OS"
echo "  $0 -n <osfilename-version.iso> for a new version"
