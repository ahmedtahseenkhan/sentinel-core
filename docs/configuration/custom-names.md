# Custom Branding Guide

## Overview

This guide explains how to customize the SentinelCore deployment with your own company branding, domain, and naming conventions.

## Placeholder Values

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `SENTINELCORE_COMPANY` | Company name | `AcmeSecurity` |
| `SENTINELCORE_DOMAIN` | Company domain | `acmesecurity.com` |
| `SENTINELCORE_MANAGER_IP` | Manager IP | `10.0.1.100` |
| `SENTINELCORE_INDEXER_IP` | Indexer IP | `10.0.1.101` |
| `SENTINELCORE_DASHBOARD_IP` | Dashboard IP | `10.0.1.102` |
| `SENTINELCORE_ADMIN_EMAIL` | Admin email | `admin@acmesecurity.com` |
| `SENTINELCORE_AUTH_PASS` | Auth password | `SecureP@ssw0rd` |
| `SENTINELCORE_AGENT_PASS` | Registration pass | `AgentP@ss` |
| `SENTINELCORE_CLUSTER_KEY` | Cluster key | `32CharacterClusterKey12345678` |

## Bulk Replace All Placeholders

```bash
#!/bin/bash
# Replace this script's values with your own
COMPANY="AcmeSecurity"
DOMAIN="acmesecurity.com"
MANAGER_IP="10.0.1.100"
INDEXER_IP="10.0.1.101"
DASHBOARD_IP="10.0.1.102"
ADMIN_EMAIL="admin@${DOMAIN}"
AUTH_PASS="YourSecurePassword"
AGENT_PASS="YourAgentPassword"
CLUSTER_KEY="$(openssl rand -hex 16)"

find . -type f \( -name "*.conf" -o -name "*.xml" -o -name "*.yml" -o -name "*.yaml" \
  -o -name "*.sh" -o -name "*.json" -o -name "*.py" -o -name "*.ps1" -o -name "*.md" \
  -o -name "manager-env-template" \) -exec sed -i '' \
  -e "s/SENTINELCORE_COMPANY/${COMPANY}/g" \
  -e "s/SENTINELCORE_DOMAIN/${DOMAIN}/g" \
  -e "s/SENTINELCORE_MANAGER_IP/${MANAGER_IP}/g" \
  -e "s/SENTINELCORE_INDEXER_IP/${INDEXER_IP}/g" \
  -e "s/SENTINELCORE_DASHBOARD_IP/${DASHBOARD_IP}/g" \
  -e "s/SENTINELCORE_ADMIN_EMAIL/${ADMIN_EMAIL}/g" \
  -e "s/SENTINELCORE_AUTH_PASS/${AUTH_PASS}/g" \
  -e "s/SENTINELCORE_AGENT_PASS/${AGENT_PASS}/g" \
  -e "s/SENTINELCORE_CLUSTER_KEY/${CLUSTER_KEY}/g" \
  {} +

echo "All placeholders replaced!"
```

## Renaming Index Prefixes

Index names use `sentinelcore-alerts-*` pattern. To change:

1. Update `indexer/templates/alerts-template.json` — change `index_patterns`
2. Update `indexer/templates/states-template.json` — change `index_patterns`
3. Update `filebeat/filebeat.yml` — change `output.elasticsearch.index`
4. Update `filebeat/templates/index-patterns.json` — change pattern names

## Custom Rule IDs

| Range | Purpose |
|-------|---------|
| 100000-100999 | General custom rules |
| 110000-110999 | PCI DSS rules |
| 111000-111999 | GDPR rules |
| 112000-112999 | HIPAA rules |
| 115000-115999 | Company policies |
