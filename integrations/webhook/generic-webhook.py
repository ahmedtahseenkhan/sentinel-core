#!/usr/bin/env python3
"""
SentinelCore - Generic Webhook Integration
============================================================================
Sends alert data to any HTTP endpoint via webhook.
Usage: python3 generic-webhook.py <alert_file> <api_key> <webhook_url>
============================================================================
"""

import json
import sys
import os
import requests
from datetime import datetime

WEBHOOK_URL = os.environ.get("SENTINELCORE_WEBHOOK_URL", "")
WEBHOOK_HEADERS = json.loads(os.environ.get("SENTINELCORE_WEBHOOK_HEADERS", "{}"))
MIN_LEVEL = int(os.environ.get("SENTINELCORE_WEBHOOK_MIN_LEVEL", "5"))


def parse_alert(alert_file: str) -> dict:
    try:
        with open(alert_file, "r") as f:
            return json.load(f)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def build_payload(alert: dict) -> dict:
    """Build a standardized webhook payload."""
    rule = alert.get("rule", {})
    agent = alert.get("agent", {})
    data = alert.get("data", {})
    level = rule.get("level", 0)

    severity = "critical" if level >= 12 else "high" if level >= 8 else "medium" if level >= 5 else "low"

    payload = {
        "source": "sentinelcore",
        "version": "1.0",
        "timestamp": alert.get("timestamp", datetime.utcnow().isoformat()),
        "alert": {
            "id": rule.get("id"),
            "level": level,
            "severity": severity,
            "description": rule.get("description"),
            "groups": rule.get("groups", []),
        },
        "agent": {
            "id": agent.get("id"),
            "name": agent.get("name"),
            "ip": agent.get("ip"),
        },
        "data": {
            "source_ip": data.get("srcip"),
            "source_user": data.get("srcuser"),
            "destination_ip": data.get("dstip"),
            "protocol": data.get("protocol"),
            "action": data.get("action"),
        },
        "mitre": rule.get("mitre", {}),
        "compliance": {
            "pci_dss": rule.get("pci_dss", []),
            "gdpr": rule.get("gdpr", []),
            "hipaa": rule.get("hipaa", []),
        },
        "full_log": alert.get("full_log", "")[:4096],
    }

    return payload


def send_webhook(url: str, payload: dict) -> bool:
    headers = {"Content-Type": "application/json"}
    headers.update(WEBHOOK_HEADERS)

    try:
        response = requests.post(url, json=payload, headers=headers, timeout=15)
        if response.status_code in [200, 201, 202, 204]:
            return True
        print(f"Webhook error: {response.status_code} - {response.text[:200]}", file=sys.stderr)
        return False
    except requests.RequestException as e:
        print(f"Webhook failed: {e}", file=sys.stderr)
        return False


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <alert_file> [api_key] <webhook_url>", file=sys.stderr)
        sys.exit(1)

    webhook_url = sys.argv[3] if len(sys.argv) >= 4 else WEBHOOK_URL
    if not webhook_url:
        print("Error: Webhook URL required", file=sys.stderr)
        sys.exit(1)

    alert = parse_alert(sys.argv[1])

    if alert.get("rule", {}).get("level", 0) < MIN_LEVEL:
        sys.exit(0)

    payload = build_payload(alert)
    success = send_webhook(webhook_url, payload)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
