# Custom Index Patterns Guide

## Default Index Patterns

| Pattern | Description |
|---------|-------------|
| `sentinelcore-alerts-*` | Security alerts |
| `sentinelcore-states-*` | Agent states (vulnerabilities, SCA, inventory) |
| `sentinelcore-monitoring-*` | Cluster monitoring data |
| `sentinelcore-statistics-*` | Statistics data |

## Modifying Index Templates

### Alerts Template

Edit `indexer/templates/alerts-template.json`:
```json
{
  "index_patterns": ["yourprefix-alerts-*"],
  "aliases": {
    "yourprefix-alerts": {}
  }
}
```

### Filebeat Output

Edit `filebeat/filebeat.yml`:
```yaml
output.elasticsearch:
  index: "yourprefix-alerts-4.x-%{+yyyy.MM.dd}"
```

## Apply Templates

```bash
bash indexer/scripts/create-indices.sh --indexer-ip 10.0.1.101 --user admin --pass YourPass
```

## Index Lifecycle Management

Configure rollover in the alerts template `settings.index.lifecycle`:
```json
{
  "lifecycle": {
    "name": "sentinelcore-alerts-policy",
    "rollover_alias": "sentinelcore-alerts"
  }
}
```

Set retention with ISM policies via the OpenSearch API.
