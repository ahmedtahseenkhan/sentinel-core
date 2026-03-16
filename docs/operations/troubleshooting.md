# Troubleshooting Guide

## Manager Issues

### Manager Won't Start
```bash
# Check logs
tail -100 /var/ossec/logs/ossec.log

# Check configuration syntax
/var/ossec/bin/wazuh-control checkconfig

# Check service status
systemctl status wazuh-manager
journalctl -u wazuh-manager --no-pager -n 50
```

### API Not Responding
```bash
# Check if API is running
curl -sk https://localhost:55000/
ss -tlnp | grep 55000

# Restart API
systemctl restart wazuh-manager
```

### High CPU/Memory Usage
```bash
# Check resource usage
top -p $(pgrep -d',' wazuh)
# Reduce log level in internal_options.conf
# Increase queue sizes if dropping events
```

## Agent Issues

### Agent Not Connecting
```bash
# Test connectivity
telnet MANAGER_IP 1514

# Check agent logs
tail -100 /var/ossec/logs/ossec.log

# Re-register agent
/var/ossec/bin/agent-auth -m MANAGER_IP -A agent-name
systemctl restart wazuh-agent
```

### Agent Shows "Disconnected"
- Verify firewall allows 1514/TCP outbound
- Check manager is running and accepting connections
- Verify agent key matches (`/var/ossec/etc/client.keys`)

## Indexer Issues

### Indexer Not Starting
```bash
# Check logs
tail -100 /var/log/wazuh-indexer/wazuh-indexer.log

# Common: heap too large
# Fix: Reduce -Xms/-Xmx in /etc/wazuh-indexer/jvm.options

# Common: certificate issue
# Fix: Verify cert paths in opensearch.yml
```

### Cluster Health Yellow/Red
```bash
curl -sk -u admin:pass https://localhost:9200/_cluster/health?pretty
curl -sk -u admin:pass https://localhost:9200/_cat/shards?v&h=index,shard,prirep,state,unassigned.reason
```

### Disk Space Full
```bash
# Check disk usage
df -h /var/lib/wazuh-indexer

# Delete old indices
curl -sk -u admin:pass -X DELETE "https://localhost:9200/sentinelcore-alerts-2024.01.*"
```

## Filebeat Issues

### Filebeat Not Sending Data
```bash
# Test output
filebeat test output

# Check logs
tail -100 /var/log/filebeat/filebeat.log

# Common: certificate mismatch
# Verify certs in /etc/filebeat/certs/ match indexer certs
```

## Certificate Issues

### "Certificate Unknown" Errors
- Verify root-ca.pem is the same CA that signed all node certs
- Ensure cert file permissions (key files: 400, cert files: 444)
- Check cert expiry: `openssl x509 -in cert.pem -noout -dates`

## Common Commands

```bash
# Manager control
/var/ossec/bin/wazuh-control status|start|stop|restart

# List agents
/var/ossec/bin/agent_control -l

# Check agent connection
/var/ossec/bin/agent_control -i <AGENT_ID>

# Restart manager
systemctl restart wazuh-manager

# Check configuration validity
/var/ossec/bin/wazuh-control checkconfig
```
