# Linux Agent Installation Guide

## Quick Install

```bash
sudo bash agent/linux/install-agent.sh \
  --manager-ip 10.0.1.100 \
  --agent-name myserver-01 \
  --agent-group linux
```

## Manual Installation

### Debian / Ubuntu

```bash
# Add repository
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring \
  --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | \
  tee /etc/apt/sources.list.d/wazuh.list

# Install
WAZUH_MANAGER="SENTINELCORE_MANAGER_IP" WAZUH_AGENT_NAME="$(hostname)" \
  apt-get install -y wazuh-agent

# Start
systemctl enable wazuh-agent && systemctl start wazuh-agent
```

### RHEL / CentOS

```bash
# Add repository
rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH
cat > /etc/yum.repos.d/wazuh.repo << EOF
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=Wazuh repository
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
EOF

# Install
WAZUH_MANAGER="SENTINELCORE_MANAGER_IP" yum install -y wazuh-agent

# Start
systemctl enable wazuh-agent && systemctl start wazuh-agent
```

## Registration

```bash
sudo bash agent/linux/register-agent.sh \
  --manager-ip 10.0.1.100 \
  --agent-name myserver-01 \
  --agent-group linux \
  --password "RegistrationPassword"
```

## Verifying Connection

```bash
# Check service
systemctl status wazuh-agent

# Check logs for connection
grep "Connected to" /var/ossec/logs/ossec.log

# From manager - list agents
curl -sk -u wazuh-wui:YourPassword https://MANAGER_IP:55000/agents?pretty
```
