#!/usr/bin/env python3
"""
SentinelCore - PagerDuty Integration
============================================================================
Sends high-severity alerts to PagerDuty for incident management.
Usage: python3 pagerduty-integration.py <alert_file> <api_key> <hook_url>
============================================================================
"""

import json
import sys
import os
import requests
from datetime import datetime

PAGERDUTY_URL = "https://events.pagerduty.com/v2/enqueue"
ROUTING_KEY = os.environ.get("SENTINELCORE_PAGERDUTY_API_KEY", "")


def parse_alert(alert_file: str) -> dict:
    try:
        with open(alert_file, "r") as f:
            return json.load(f)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def get_severity(level: int) -> str:
    if level >= 12:
        return "critical"
    elif level >= 8:
        return "error"
    elif level >= 5:
        return "warning"
    return "info"


def create_pagerduty_event(alert: dict) -> dict:
    rule = alert.get("rule", {})
    agent = alert.get("agent", {})
    data = alert.get("data", {})
    level = rule.get("level", 0)

    event = {
        "routing_key": ROUTING_KEY,
        "event_action": "trigger",
        "dedup_key": f"sentinelcore-{rule.get('id', 'unknown')}-{agent.get('id', 'unknown')}-{data.get('srcip', 'none')}",
        "payload": {
            "summary": f"[SentinelCore] {rule.get('description', 'Security Alert')} - Agent: {agent.get('name', 'unknown')}",
            "source": f"sentinelcore-{agent.get('name', 'unknown')}",
            "severity": get_severity(level),
            "timestamp": alert.get("timestamp", datetime.utcnow().isoformat()),
            "component": "SentinelCore Security",
            "group": ", ".join(rule.get("groups", ["security"])),
            "class": f"rule-{rule.get('id', 'unknown')}",
            "custom_details": {
                "rule_id": rule.get("id"),
                "rule_level": level,
                "agent_name": agent.get("name"),
                "agent_ip": agent.get("ip"),
                "source_ip": data.get("srcip"),
                "source_user": data.get("srcuser"),
                "full_log": alert.get("full_log", "")[:1024],
                "mitre_ids": rule.get("mitre", {}).get("id", []),
            },
        },
        "links": [
            {
                "href": f"https://SENTINELCORE_MANAGER_IP:443/app/wazuh#/overview/?tab=general&tabView=panels",
                "text": "View in SentinelCore Dashboard",
            }
        ],
    }
    return event


def send_to_pagerduty(event: dict) -> bool:
    try:
        response = requests.post(
            PAGERDUTY_URL,
            json=event,
            headers={"Content-Type": "application/json"},
            timeout=10,
        )
        if response.status_code == 202:
            return True
        print(f"PagerDuty error: {response.status_code} - {response.text}", file=sys.stderr)
        return False
    except requests.RequestException as e:
        print(f"PagerDuty request failed: {e}", file=sys.stderr)
        return False


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <alert_file> [api_key] [hook_url]", file=sys.stderr)
        sys.exit(1)

    global ROUTING_KEY
    if len(sys.argv) >= 3 and sys.argv[2]:
        ROUTING_KEY = sys.argv[2]

    if not ROUTING_KEY:
        print("Error: PagerDuty routing key required", file=sys.stderr)
        sys.exit(1)

    alert = parse_alert(sys.argv[1])

    # Only trigger for level 10+
    if alert.get("rule", {}).get("level", 0) < 10:
        sys.exit(0)

    event = create_pagerduty_event(alert)
    success = send_to_pagerduty(event)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
