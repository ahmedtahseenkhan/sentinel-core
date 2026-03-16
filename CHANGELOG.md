# Changelog

All notable changes to the SentinelCore Wazuh deployment will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Dashboard custom branding
- Multi-cluster support
- Automated compliance reporting

---

## [1.0.0] - 2026-03-15

### Added
- Initial repository structure
- Manager configuration with SentinelCore branding
- Indexer configuration with custom index prefixes (`sentinelcore-alerts-*`)
- Linux and Windows agent configurations and installers
- Certificate generation and renewal scripts
- Filebeat configuration with custom pipelines
- Integration scripts (Slack, PagerDuty, TheHive, Email, Webhook)
- Compliance frameworks (PCI-DSS, GDPR, HIPAA, MITRE ATT&CK)
- Monitoring setup (Prometheus, Grafana, health checks)
- Comprehensive documentation
- Utility scripts for deployment, updates, and backup

### Security
- TLS certificate management for all components
- Security plugin initialization for indexer
- Agent authentication and registration scripts

---

## Version History Template

<!-- Use this template for future versions:

## [X.Y.Z] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes to existing features

### Deprecated
- Features that will be removed in future versions

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security-related changes
-->
