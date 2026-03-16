#!/usr/bin/env python3
"""
SentinelCore - TheHive Case Management Integration
============================================================================
Creates TheHive cases from high-severity SentinelCore alerts.
Usage: python3 thehive-cases.py <alert_file> <api_key> <hook_url>
============================================================================
"""

import json
import sys
import os
import requests
from datetime import datetime

THEHIVE_URL = os.environ.get("SENTINELCORE_THEHIVE_URL", "https://SENTINELCORE_THEHIVE_HOST:9000")
THEHIVE_API_KEY = os.environ.get("SENTINELCORE_THEHIVE_API_KEY", "")
MIN_LEVEL = 10


def parse_alert(alert_file: str) -> dict:
    try:
        with open(alert_file, "r") as f:
            return json.load(f)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def get_severity(level: int) -> int:
    """Map Wazuh level to TheHive severity (1-4)."""
    if level >= 12:
        return 4  # Critical
    elif level >= 8:
        return 3  # High
    elif level >= 5:
        return 2  # Medium
    return 1  # Low


def get_tlp(level: int) -> int:
    """Map alert level to TLP."""
    if level >= 12:
        return 3  # TLP:RED
    elif level >= 8:
        return 2  # TLP:AMBER
    return 1  # TLP:GREEN


def create_alert(alert: dict) -> dict:
    """Create a TheHive alert from a Wazuh alert."""
    rule = alert.get("rule", {})
    agent = alert.get("agent", {})
    data = alert.get("data", {})
    level = rule.get("level", 0)

    # Build tags
    tags = ["SentinelCore", f"level:{level}"]
    tags.extend(rule.get("groups", []))
    mitre_ids = rule.get("mitre", {}).get("id", [])
    tags.extend([f"mitre:{m}" for m in mitre_ids])

    # Build observables
    observables = []
    if data.get("srcip"):
        observables.append({
            "dataType": "ip",
            "data": data["srcip"],
            "message": "Source IP from alert",
            "tlp": get_tlp(level),
        })
    if data.get("dstip"):
        observables.append({
            "dataType": "ip",
            "data": data["dstip"],
            "message": "Destination IP from alert",
            "tlp": get_tlp(level),
        })
    if data.get("srcuser"):
        observables.append({
            "dataType": "other",
            "data": data["srcuser"],
            "message": "Source user from alert",
            "tlp": get_tlp(level),
        })
    if agent.get("name"):
        observables.append({
            "dataType": "hostname",
            "data": agent["name"],
            "message": "Agent hostname",
            "tlp": get_tlp(level),
        })

    thehive_alert = {
        "title": f"[SentinelCore] {rule.get('description', 'Security Alert')}",
        "description": (
            f"## SentinelCore Security Alert\n\n"
            f"**Rule:** {rule.get('id', 'N/A')} - {rule.get('description', 'N/A')}\n"
            f"**Level:** {level}\n"
            f"**Agent:** {agent.get('name', 'N/A')} ({agent.get('ip', 'N/A')})\n"
            f"**Groups:** {', '.join(rule.get('groups', []))}\n\n"
            f"### Full Log\n```\n{alert.get('full_log', 'N/A')[:2048]}\n```\n\n"
            f"### MITRE ATT&CK\n{', '.join(mitre_ids) if mitre_ids else 'N/A'}\n"
        ),
        "severity": get_severity(level),
        "date": int(datetime.utcnow().timestamp() * 1000),
        "tags": tags,
        "tlp": get_tlp(level),
        "type": "sentinelcore-alert",
        "source": "SentinelCore",
        "sourceRef": f"sc-{rule.get('id', '0')}-{agent.get('id', '0')}-{int(datetime.utcnow().timestamp())}",
        "artifacts": observables,
    }

    return thehive_alert


def send_to_thehive(thehive_alert: dict) -> bool:
    try:
        response = requests.post(
            f"{THEHIVE_URL}/api/alert",
            json=thehive_alert,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {THEHIVE_API_KEY}",
            },
            timeout=10,
            verify=False,
        )
        if response.status_code in [200, 201]:
            return True
        print(f"TheHive error: {response.status_code} - {response.text}", file=sys.stderr)
        return False
    except requests.RequestException as e:
        print(f"TheHive request failed: {e}", file=sys.stderr)
        return False


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <alert_file> [api_key] [hook_url]", file=sys.stderr)
        sys.exit(1)

    global THEHIVE_API_KEY
    if len(sys.argv) >= 3 and sys.argv[2]:
        THEHIVE_API_KEY = sys.argv[2]

    if not THEHIVE_API_KEY:
        print("Error: TheHive API key required", file=sys.stderr)
        sys.exit(1)

    alert = parse_alert(sys.argv[1])

    if alert.get("rule", {}).get("level", 0) < MIN_LEVEL:
        sys.exit(0)

    thehive_alert = create_alert(alert)
    success = send_to_thehive(thehive_alert)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
