# Manager Installation Guide

## Prerequisites

- **OS**: Ubuntu 20.04+, Debian 10+, RHEL 8+, CentOS 8+, Rocky 8+
- **RAM**: Minimum 4GB (8GB+ recommended)
- **CPU**: 2+ cores
- **Disk**: 50GB+ (SSD recommended)
- **Network**: Ports 1514/TCP, 1515/TCP, 55000/TCP open

## Quick Install

```bash
cd manager/scripts
sudo bash install-manager.sh --manager-ip <YOUR_IP> --api-pass <YOUR_PASSWORD>
```

## Step-by-Step Installation

### 1. Prepare the System

```bash
# Update system
sudo apt update && sudo apt upgrade -y   # Debian/Ubuntu
sudo yum update -y                        # RHEL/CentOS

# Set hostname
sudo hostnamectl set-hostname sentinelcore-manager-1
```

### 2. Run the Installer

```bash
sudo bash manager/scripts/install-manager.sh \
  --manager-ip 10.0.1.100 \
  --api-pass "YourSecurePassword" \
  --version 4.9.0
```

### 3. Post-Installation Configuration

```bash
sudo bash manager/scripts/configure-manager.sh \
  --email admin@yourcompany.com \
  --domain yourcompany.com \
  --agent-pass "AgentRegistrationPass"
```

### 4. Deploy Certificates

```bash
sudo cp certificates/certs/sentinelcore-manager-1.pem /var/ossec/etc/sslmanager.cert
sudo cp certificates/certs/sentinelcore-manager-1-key.pem /var/ossec/etc/sslmanager.key
sudo cp certificates/certs/root-ca.pem /var/ossec/etc/
sudo chown wazuh:wazuh /var/ossec/etc/sslmanager.*
sudo systemctl restart wazuh-manager
```

### 5. Verify

```bash
sudo systemctl status wazuh-manager
curl -sk https://localhost:55000/ -u wazuh-wui:YourPassword
```

## Configuration Files

| File | Location | Description |
|------|----------|-------------|
| `ossec.conf` | `/var/ossec/etc/` | Main configuration |
| `local_rules.xml` | `/var/ossec/etc/rules/` | Custom rules |
| `local_decoder.xml` | `/var/ossec/etc/decoders/` | Custom decoders |
| `agent.conf` | `/var/ossec/etc/shared/` | Shared agent config |

## Firewall Rules

```bash
# UFW
sudo ufw allow 1514/tcp  # Agent communication
sudo ufw allow 1515/tcp  # Agent registration
sudo ufw allow 55000/tcp # API

# firewalld
sudo firewall-cmd --permanent --add-port={1514,1515,55000}/tcp
sudo firewall-cmd --reload
```
