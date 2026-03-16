# Indexer Installation Guide

## Prerequisites

- **RAM**: Minimum 4GB (16GB+ recommended for production)
- **Disk**: 100GB+ SSD
- **Java**: Bundled with Wazuh Indexer

## Quick Install

```bash
cd indexer/scripts
sudo bash install-indexer.sh --indexer-ip <YOUR_IP> --node-name sentinelcore-indexer-1
```

## Step-by-Step

### 1. Install the Indexer

```bash
sudo bash indexer/scripts/install-indexer.sh \
  --indexer-ip 10.0.1.101 \
  --node-name sentinelcore-indexer-1
```

### 2. Deploy Certificates

```bash
sudo mkdir -p /etc/wazuh-indexer/certs
sudo cp certificates/certs/root-ca.pem /etc/wazuh-indexer/certs/
sudo cp certificates/certs/sentinelcore-indexer-1.pem /etc/wazuh-indexer/certs/indexer.pem
sudo cp certificates/certs/sentinelcore-indexer-1-key.pem /etc/wazuh-indexer/certs/indexer-key.pem
sudo cp certificates/certs/admin.pem /etc/wazuh-indexer/certs/
sudo cp certificates/certs/admin-key.pem /etc/wazuh-indexer/certs/
sudo chown -R wazuh-indexer:wazuh-indexer /etc/wazuh-indexer/certs/
sudo chmod 400 /etc/wazuh-indexer/certs/*-key.pem
sudo systemctl restart wazuh-indexer
```

### 3. Initialize Security

```bash
sudo bash indexer/scripts/init-security.sh
```

### 4. Create Custom Indices

```bash
sudo bash indexer/scripts/create-indices.sh \
  --indexer-ip 10.0.1.101 \
  --user admin \
  --pass YourAdminPassword
```

### 5. Verify

```bash
curl -sk -u admin:YourPassword https://10.0.1.101:9200/_cluster/health?pretty
curl -sk -u admin:YourPassword https://10.0.1.101:9200/_cat/indices/sentinelcore-*?v
```

## JVM Tuning

Edit `/etc/wazuh-indexer/jvm.options`:
- Set heap to 50% of available RAM (max 32GB)
- Both `-Xms` and `-Xmx` must be equal

## Multi-Node Cluster

Edit `opensearch.yml` and uncomment the multi-node discovery section, adding all node IPs.
