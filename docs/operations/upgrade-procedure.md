# Upgrade Procedure

## Pre-Upgrade Checklist

- [ ] Review [changelog](https://documentation.wazuh.com/current/release-notes/) for target version
- [ ] Backup all configurations: `sudo bash manager/scripts/backup-manager.sh`
- [ ] Test upgrade in staging environment first
- [ ] Notify team of maintenance window
- [ ] Verify disk space availability

## Upgrade Order

**Always upgrade in this order:**
1. Manager (master node first for clusters)
2. Indexer
3. Dashboard
4. Agents

## Manager Upgrade

```bash
# Backup
sudo bash manager/scripts/backup-manager.sh

# Stop
sudo systemctl stop wazuh-manager

# Upgrade (Debian/Ubuntu)
sudo apt-get update
sudo apt-get install wazuh-manager=NEW_VERSION-1

# Upgrade (RHEL/CentOS)
sudo yum install wazuh-manager-NEW_VERSION

# Start
sudo systemctl start wazuh-manager

# Verify
/var/ossec/bin/wazuh-control info | grep VERSION
```

## Indexer Upgrade

```bash
sudo systemctl stop wazuh-indexer
sudo apt-get install wazuh-indexer=NEW_VERSION-1  # or yum
sudo systemctl start wazuh-indexer
```

## Agent Upgrade

### Using the Manager API
```bash
curl -sk -u wazuh-wui:pass -X PUT "https://MANAGER:55000/agents/upgrade?agents_list=001,002,003"
```

### Using the Script
```bash
sudo bash agent/common/agent-upgrade.sh --version NEW_VERSION
```

## Rollback

If the upgrade fails:
```bash
# Restore from backup
sudo systemctl stop wazuh-manager
sudo tar -xzf /var/backups/sentinelcore/sentinelcore-manager-backup-TIMESTAMP.tar.gz -C /
sudo systemctl start wazuh-manager
```

## Post-Upgrade Verification

```bash
sudo bash monitoring/health-checks/check-cluster.sh
sudo bash monitoring/health-checks/check-agents.sh
```
