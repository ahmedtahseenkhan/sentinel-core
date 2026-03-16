# SentinelCore Wazuh

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-green.svg)](VERSION)
[![Wazuh](https://img.shields.io/badge/Wazuh-4.x-orange.svg)](https://wazuh.com)
[![Status](https://img.shields.io/badge/status-production--ready-brightgreen.svg)]()

> **Custom-branded Wazuh deployment by SentinelCore** — Enterprise-grade security monitoring, threat detection, and compliance management.

---

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_ORG/SentinelCoreV1.git
cd SentinelCoreV1

# 2. Generate certificates
cd certificates && sudo bash generate-certs.sh

# 3. Deploy all components
cd ../scripts && sudo bash deploy-all.sh

# 4. Access the dashboard
# https://YOUR_MANAGER_IP:443
```

## 📋 Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **OS** | Ubuntu 20.04 / RHEL 8 | Ubuntu 22.04 / RHEL 9 |
| **CPU** | 2 cores | 4+ cores |
| **RAM** | 4 GB | 8+ GB |
| **Disk** | 50 GB | 200+ GB (SSD) |
| **Network** | 1514/TCP, 1515/TCP, 9200/TCP, 55000/TCP | Same |

## 📁 Repository Structure

```
SentinelCoreV1/
├── manager/                  # Wazuh Manager configuration
│   ├── etc/                  # Configuration files (ossec.conf, rules, decoders)
│   ├── scripts/              # Installation and management scripts
│   └── templates/            # Environment variable templates
├── indexer/                  # Wazuh Indexer (OpenSearch) configuration
│   ├── templates/            # Index templates
│   ├── scripts/              # Installation and security scripts
│   └── performance/          # Performance tuning
├── agent/                    # Agent configurations
│   ├── linux/                # Linux agent configs and installers
│   ├── windows/              # Windows agent configs and installers
│   └── common/               # Shared modules and configs
├── certificates/             # TLS certificate management
├── filebeat/                 # Filebeat configuration and pipelines
├── integrations/             # Third-party integrations
│   ├── slack/                # Slack notifications
│   ├── pagerduty/            # PagerDuty integration
│   ├── thehive/              # TheHive case management
│   ├── smtp/                 # Email alerts
│   └── webhook/              # Generic webhook
├── compliance/               # Compliance frameworks
│   ├── pci-dss/              # PCI DSS rules and reports
│   ├── gdpr/                 # GDPR rules
│   ├── hipaa/                # HIPAA rules
│   ├── mitre/                # MITRE ATT&CK mappings
│   └── custom/               # Custom company policies
├── monitoring/               # Monitoring and health checks
│   ├── prometheus/           # Prometheus metrics
│   ├── grafana/              # Grafana dashboards
│   └── health-checks/        # Health check scripts
├── docs/                     # Comprehensive documentation
│   ├── installation/         # Installation guides
│   ├── configuration/        # Configuration guides
│   ├── operations/           # Operations and troubleshooting
│   └── api/                  # API usage examples
└── scripts/                  # Global utility scripts
```

## 🔧 Configuration

All configuration files use placeholder values for easy customization:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `SENTINELCORE_MANAGER_IP` | Manager server IP address | `10.0.1.100` |
| `SENTINELCORE_INDEXER_IP` | Indexer server IP address | `10.0.1.101` |
| `SENTINELCORE_COMPANY` | Your company name | `SentinelCore` |
| `SENTINELCORE_DOMAIN` | Your domain | `sentinelcore.com` |
| `SENTINELCORE_ADMIN_EMAIL` | Admin email address | `admin@sentinelcore.com` |
| `SENTINELCORE_AUTH_PASS` | Authentication password | `(secure password)` |

### Find and Replace

```bash
# Replace all placeholders at once
find . -type f \( -name "*.conf" -o -name "*.xml" -o -name "*.yml" -o -name "*.sh" -o -name "*.json" -o -name "*.ps1" -o -name "*.py" \) \
  -exec sed -i 's/SENTINELCORE_MANAGER_IP/10.0.1.100/g' {} +
```

## 📖 Documentation

- [Manager Installation](docs/installation/manager-install.md)
- [Indexer Installation](docs/installation/indexer-install.md)
- [Linux Agent Installation](docs/installation/agent-install-linux.md)
- [Windows Agent Installation](docs/installation/agent-install-windows.md)
- [Offline Installation](docs/installation/offline-install.md)
- [Custom Branding Guide](docs/configuration/custom-names.md)
- [Troubleshooting](docs/operations/troubleshooting.md)
- [API Examples](docs/api/api-examples.md)

## 🛡️ Components

### Manager
The SentinelCore Manager is the central component that collects, analyzes, and correlates security data from deployed agents.

### Indexer
Based on OpenSearch, the SentinelCore Indexer provides scalable storage and search capabilities for security events.

### Agents
Lightweight agents deployed on endpoints to collect security data, perform file integrity monitoring, vulnerability detection, and more.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## 📞 Support

- **Email**: support@SENTINELCORE_DOMAIN
- **Documentation**: [docs/](docs/)
- **Issues**: Use GitHub Issues for bug reports and feature requests

---

*Built with ❤️ by SentinelCore Security Team*
