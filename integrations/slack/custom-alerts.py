#!/usr/bin/env python3
"""
SentinelCore - Custom Slack Alert Processor
============================================================================
Advanced alert processing with filtering, grouping, and rich formatting.
Usage: python3 custom-alerts.py <alert_file> <api_key> <webhook_url>
============================================================================
"""

import json
import sys
import os
import requests
from datetime import datetime

# ========================= Configuration ====================================
WEBHOOK_URL = os.environ.get("SENTINELCORE_SLACK_WEBHOOK_URL", "")
MIN_LEVEL = int(os.environ.get("SENTINELCORE_SLACK_MIN_LEVEL", "8"))
EXCLUDED_RULES = os.environ.get("SENTINELCORE_SLACK_EXCLUDED_RULES", "").split(",")

# Severity mapping
SEVERITY_MAP = {
    range(0, 4): {"label": "Low", "color": "#36A64F", "emoji": ":white_check_mark:"},
    range(4, 8): {"label": "Medium", "color": "#FFD700", "emoji": ":warning:"},
    range(8, 12): {"label": "High", "color": "#FF8C00", "emoji": ":exclamation:"},
    range(12, 16): {"label": "Critical", "color": "#FF0000", "emoji": ":rotating_light:"},
}


def get_severity(level: int) -> dict:
    """Get severity info based on alert level."""
    for level_range, info in SEVERITY_MAP.items():
        if level in level_range:
            return info
    return SEVERITY_MAP[range(0, 4)]


def parse_alert(alert_file: str) -> dict:
    """Parse alert JSON file."""
    try:
        with open(alert_file, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Error reading alert file: {e}", file=sys.stderr)
        sys.exit(1)


def build_slack_message(alert: dict) -> dict:
    """Build rich Slack message from alert data."""
    rule = alert.get("rule", {})
    agent = alert.get("agent", {})
    data = alert.get("data", {})
    level = rule.get("level", 0)
    severity = get_severity(level)

    # Extract MITRE info if available
    mitre_info = ""
    mitre = rule.get("mitre", {})
    if mitre:
        tactics = ", ".join(mitre.get("tactic", []))
        techniques = ", ".join(mitre.get("id", []))
        mitre_info = f"\n*MITRE ATT&CK:* {tactics} ({techniques})"

    # Build fields
    fields = [
        {"title": "Rule ID", "value": str(rule.get("id", "N/A")), "short": True},
        {"title": "Severity", "value": f"{severity['emoji']} {severity['label']} (Level {level})", "short": True},
        {"title": "Agent", "value": f"{agent.get('name', 'N/A')} ({agent.get('ip', 'N/A')})", "short": True},
    ]

    if data.get("srcip"):
        fields.append({"title": "Source IP", "value": data["srcip"], "short": True})

    if data.get("srcuser"):
        fields.append({"title": "User", "value": data["srcuser"], "short": True})

    # Compliance tags
    compliance = []
    for framework in ["pci_dss", "gdpr", "hipaa", "nist_800_53"]:
        tags = rule.get(framework, [])
        if tags:
            compliance.append(f"{framework.upper()}: {', '.join(tags)}")
    if compliance:
        fields.append({"title": "Compliance", "value": "\n".join(compliance), "short": False})

    payload = {
        "username": "SentinelCore Security",
        "icon_emoji": ":shield:",
        "attachments": [
            {
                "color": severity["color"],
                "title": f"{severity['emoji']} {rule.get('description', 'SentinelCore Alert')}",
                "text": f"*Rule Groups:* {', '.join(rule.get('groups', []))}{mitre_info}",
                "fields": fields,
                "footer": "SentinelCore | Security Monitoring",
                "ts": int(datetime.now().timestamp()),
            }
        ],
    }

    return payload


def send_to_slack(webhook_url: str, payload: dict) -> bool:
    """Send message to Slack."""
    try:
        response = requests.post(
            webhook_url,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=10,
        )
        return response.status_code == 200
    except requests.RequestException as e:
        print(f"Slack request failed: {e}", file=sys.stderr)
        return False


def main():
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <alert_file> <api_key> <webhook_url>", file=sys.stderr)
        sys.exit(1)

    alert_file = sys.argv[1]
    webhook_url = sys.argv[3] if sys.argv[3] else WEBHOOK_URL

    if not webhook_url:
        print("Error: No webhook URL provided", file=sys.stderr)
        sys.exit(1)

    alert = parse_alert(alert_file)
    rule = alert.get("rule", {})

    # Filter by level
    if rule.get("level", 0) < MIN_LEVEL:
        sys.exit(0)

    # Filter excluded rules
    if str(rule.get("id", "")) in EXCLUDED_RULES:
        sys.exit(0)

    payload = build_slack_message(alert)
    success = send_to_slack(webhook_url, payload)

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
