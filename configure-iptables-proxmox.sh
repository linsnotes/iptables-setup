#!/bin/bash

# Check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Function to prompt the user for installing iptables-persistent or iptables-services
install_persistent() {
  read -p "iptables-persistent/iptables-services is not installed. Would you like to install it now? (yes/no): " choice
  case "$choice" in
    yes|Yes|y|Y )
      if [ -x "$(command -v apt-get)" ]; then
        apt-get update && apt-get install -y iptables-persistent || { echo "Installation failed."; exit 1; }
        echo "iptables-persistent installed successfully."
      elif [ -x "$(command -v yum)" ]; then
        yum install -y iptables-services || { echo "Installation failed."; exit 1; }
        echo "iptables-services installed successfully."
      else
        echo "Package manager not recognized. Please install iptables-persistent or iptables-services manually."
        exit 1
      fi
      ;;
    no|No|n|N )
      echo "Skipping installation. Please note that you will need to run this script every time the system reboots to apply the rules."
      ;;
    * )
      echo "Invalid choice. Please answer yes or no."
      install_persistent
      ;;
  esac
}

# Check if the system is Debian-based and if iptables-persistent is installed
if [ -x "$(command -v dpkg-query)" ]; then
  echo "Detected Debian-based system."
  if dpkg-query -W -f='${Status}' iptables-persistent 2>/dev/null | grep -q "ok installed"; then
    echo "iptables-persistent is already installed."
  else
    install_persistent
  fi
  SYSTEM="debian"
# Check if the system is CentOS/RHEL-based and if iptables-services is installed
elif [ -x "$(command -v rpm)" ]; then
  echo "Detected CentOS/RHEL-based system."
  if rpm -q iptables-services >/dev/null 2>&1; then
    echo "iptables-services is already installed."
  else
    install_persistent
  fi
  SYSTEM="redhat"
else
  echo "Unsupported system. Please manually ensure iptables-persistent or iptables-services is installed."
  exit 1
fi

# Flush all existing rules to start with a clean slate
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -t raw -F
iptables -t raw -X

# Set default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established and related connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Track new SSH connection attempts and add source IP to the "SSH" recent list
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH

# Drop packets if the source IP has made more than 3 connection attempts within the last 60 seconds
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP

# Allow SSH connections if they do not exceed the rate limit
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow Proxmox web interface
#iptables -A INPUT -p tcp --dport 8006 -j ACCEPT

# Optional: Allow HTTP traffic (port 80)
iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Optional: Allow HTTPS traffic (port 443)
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow specific traffic on vmbr0 (modify as needed)
iptables -A INPUT -i vmbr0 -j ACCEPT
iptables -A FORWARD -i vmbr0 -j ACCEPT
iptables -A FORWARD -o vmbr0 -j ACCEPT

# Allow limited ICMP (Ping) requests
iptables -A INPUT -p icmp --icmp-type 8 -m limit --limit 1/second -j ACCEPT
iptables -A INPUT -p icmp --icmp-type 8 -j DROP

# Drop invalid packets
iptables -A INPUT -m state --state INVALID -j DROP

# Log dropped packets
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables-input: " --log-level 4

# NAT for vmbr0
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE  # Replace eth0 with the actual host interface if different

# Save the rules
iptables-save > /etc/iptables/rules.v4

echo "iptables rules have been set and saved."
