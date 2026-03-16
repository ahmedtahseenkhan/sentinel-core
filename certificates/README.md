# SentinelCore - Certificate Management

## Overview

This directory manages TLS certificates for all SentinelCore components (Indexer, Manager, Dashboard, Filebeat).

## Quick Start

```bash
# 1. Edit config template with your node details
cp config.yml.template config.yml
# Edit config.yml with your actual IPs and node names

# 2. Generate certificates
sudo bash generate-certs.sh

# 3. Deploy certificates to each component
# (see deployment section below)
```

## Files

| File | Description |
|------|-------------|
| `config.yml.template` | Node configuration template |
| `generate-certs.sh` | Generate all certificates |
| `renew-certs.sh` | Renew expiring certificates |
| `certs/` | Generated certificates (gitignored) |

## Generated Certificates

After running `generate-certs.sh`, the `certs/` directory will contain:

| Certificate | Used By |
|-------------|---------|
| `root-ca.pem` / `root-ca-key.pem` | Root CA (all components) |
| `admin.pem` / `admin-key.pem` | Security plugin admin |
| `sentinelcore-indexer-1.pem` | Indexer node |
| `sentinelcore-manager-1.pem` | Manager node |
| `sentinelcore-dashboard-1.pem` | Dashboard node |
| `filebeat.pem` | Filebeat |

## Deployment

### Indexer
```bash
sudo cp certs/root-ca.pem certs/sentinelcore-indexer-1.pem certs/sentinelcore-indexer-1-key.pem /etc/wazuh-indexer/certs/
sudo cp certs/sentinelcore-indexer-1.pem /etc/wazuh-indexer/certs/indexer.pem
sudo cp certs/sentinelcore-indexer-1-key.pem /etc/wazuh-indexer/certs/indexer-key.pem
sudo chown -R wazuh-indexer:wazuh-indexer /etc/wazuh-indexer/certs/
sudo chmod 400 /etc/wazuh-indexer/certs/*-key.pem
```

### Manager
```bash
sudo cp certs/root-ca.pem /var/ossec/etc/
sudo cp certs/sentinelcore-manager-1.pem /var/ossec/etc/sslmanager.cert
sudo cp certs/sentinelcore-manager-1-key.pem /var/ossec/etc/sslmanager.key
sudo chown wazuh:wazuh /var/ossec/etc/sslmanager.*
```

### Filebeat
```bash
sudo cp certs/root-ca.pem certs/filebeat.pem certs/filebeat-key.pem /etc/filebeat/certs/
sudo chown root:root /etc/filebeat/certs/*
sudo chmod 400 /etc/filebeat/certs/*-key.pem
```

## Renewal

```bash
# Check and renew certificates expiring within 30 days
sudo bash renew-certs.sh --days-before 30

# After renewal, restart all services
sudo systemctl restart wazuh-indexer wazuh-manager wazuh-dashboard filebeat
```

## Security Notes

- **Never commit** the `certs/` directory to version control
- Store `root-ca-key.pem` in a secure, offline location
- Use strong key sizes (2048-bit minimum, 4096-bit recommended for CA)
- Monitor certificate expiry with the renewal script in a cron job
