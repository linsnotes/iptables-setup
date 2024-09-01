#!/bin/bash

# This script configures iptables rules for multiple services.
# It checks for the installation of iptables-persistent (Debian/Ubuntu) or iptables-services (CentOS/RHEL).
# If not installed, it prompts the user to install the package to save rules across reboots.
# If not installed, the user will need to run this script every time the system reboots to apply the rules.

# To use this script:
# 1. Save it to a file, e.g., configure-iptables.sh
# 2. Make it executable: chmod +x configure-iptables.sh
# 3. Run the script: sudo ./configure-iptables.sh

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

# Set default policies to drop all incoming and forwarding traffic, allow outgoing
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established and related connections
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Track new SSH connection attempts and add source IP to the "SSH" recent list
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH

# Drop packets if the source IP has made more than 3 connection attempts within the last 60 seconds
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP

# Allow SSH connections if they do not exceed the rate limit
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Optional: Allow HTTP traffic (port 80)
# iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Optional: Allow HTTPS traffic (port 443)
# iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Optional: Allow custom application traffic (port 8080)
# iptables -A INPUT -p tcp --dport 8080 -j ACCEPT

# Optional: Allow ICMP (ping) requests
# iptables -A INPUT -p icmp --icmp-type 8 -j ACCEPT

# Log packets that would be dropped, with rate limiting
iptables -A INPUT -m limit --limit 5/min --limit-burst 10 -j LOG --log-prefix "iptables denied: " --log-level 7

# Save the configuration so it persists across reboots
if [ "$SYSTEM" == "debian" ]; then
  iptables-save > /etc/iptables/rules.v4
  echo "iptables rules saved to /etc/iptables/rules.v4"
elif [ "$SYSTEM" == "redhat" ]; then
  service iptables save
  echo "iptables rules saved using 'service iptables save'"
fi

echo "iptables rules configured and saved."
echo "To verify if the rules are correctly set, run the following command:"
echo "  sudo iptables -L -v"
echo "If you reboot your system, run the same command again to ensure the rules are still in place."
echo "To reset iptables to the default settings, run the following commands in order:"
echo "  sudo iptables -F"
echo "  sudo iptables -X"
echo "  sudo iptables -t nat -F"
echo "  sudo iptables -t nat -X"
echo "  sudo iptables -t mangle -F"
echo "  sudo iptables -t mangle -X"
echo "  sudo iptables -t raw -F"
echo "  sudo iptables -t raw -X"
echo "  sudo iptables -P INPUT ACCEPT"
echo "  sudo iptables -P FORWARD ACCEPT"
echo "  sudo iptables -P OUTPUT ACCEPT"
echo "  sudo iptables-save > /etc/iptables/rules.v4 (Debian/Ubuntu)"
echo "  sudo service iptables save (CentOS/RHEL)"
echo "To check iptables logs for dropped packets, you can use the following commands based on your system:"
echo "  sudo tail -f /var/log/syslog | grep 'iptables denied:'  # For Debian/Ubuntu systems"
echo "  sudo tail -f /var/log/messages | grep 'iptables denied:'  # For CentOS/RHEL systems"
echo "  sudo dmesg | grep 'iptables denied:'  # To see recent log entries"
echo "  sudo journalctl -f | grep 'iptables denied:'  # For systems using systemd"
