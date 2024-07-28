# Configure iptables Rules Script

## Description

This script configures iptables rules to secure a Linux system by setting default policies, allowing specific types of traffic (like SSH), and logging dropped packets. It also checks for and installs necessary packages (`iptables-persistent` on Debian/Ubuntu or `iptables-services` on CentOS/RHEL) to ensure rules persist across reboots.

## Prerequisites

- A Linux system (Debian/Ubuntu or CentOS/RHEL)
- Root or sudo privileges

## Usage

1. **Save the Script**

   Save the script to a file, e.g., `configure-iptables.sh`.

   ```bash
   wget https://path-to-your-script/configure-iptables.sh
   ```

2. **Make the Script Executable**

   ```bash
   chmod +x configure-iptables.sh
   ```

3. **Run the Script**

   ```bash
   sudo ./configure-iptables.sh
   ```

## Features

- Sets default iptables policies:
  - Drops all incoming and forwarding traffic.
  - Allows outgoing traffic.
- Allows loopback traffic and established/related connections.
- Allows SSH traffic (port 22).
- Optional rules for HTTP (port 80), HTTPS (port 443), custom application traffic (port 8080), and ICMP (ping) requests.
- Logs dropped packets with rate limiting.
- Prompts for installing `iptables-persistent` or `iptables-services` if not already installed.
- Saves iptables rules to persist across reboots.

## Instructions

### To Verify iptables Rules

Run the following command to verify if the rules are correctly set:

```bash
sudo iptables -L -v
```

### To Reset iptables to Default Settings

Run the following commands in order:

```bash
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X
sudo iptables -t raw -F
sudo iptables -t raw -X
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
```

For Debian/Ubuntu:

```bash
sudo iptables-save > /etc/iptables/rules.v4
```

For CentOS/RHEL:

```bash
sudo service iptables save
```

### To Check iptables Logs for Dropped Packets

For Debian/Ubuntu systems:

```bash
sudo tail -f /var/log/syslog | grep 'iptables denied:'
```

For CentOS/RHEL systems:

```bash
sudo tail -f /var/log/messages | grep 'iptables denied:'
```

To see recent log entries:

```bash
sudo dmesg | grep 'iptables denied:'
```

For systems using systemd:

```bash
sudo journalctl -f | grep 'iptables denied:'
```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request with any improvements or suggestions.

## License

This project is licensed under the MIT License.
