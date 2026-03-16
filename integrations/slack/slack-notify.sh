#!/usr/bin/env bash
# ============================================================================
# SentinelCore - Slack Notification Integration
# ============================================================================
# Sends Wazuh alerts to Slack via webhook.
# Place in /var/ossec/integrations/ and configure in ossec.conf.
#
# ossec.conf integration block:
#   <integration>
#     <name>custom-slack-notify</name>
#     <hook_url>https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK</hook_url>
#     <level>8</level>
#     <alert_format>json</alert_format>
#   </integration>
# ============================================================================

WEBHOOK_URL="$3"
ALERT_FILE="$1"

if [[ -z "${WEBHOOK_URL}" || -z "${ALERT_FILE}" ]]; then
    echo "Usage: $0 <alert_file> <api_key> <webhook_url>" >&2
    exit 1
fi

# Read alert JSON
ALERT_JSON=$(cat "${ALERT_FILE}")

# Extract fields
RULE_LEVEL=$(echo "${ALERT_JSON}" | jq -r '.rule.level // "N/A"')
RULE_DESC=$(echo "${ALERT_JSON}" | jq -r '.rule.description // "No description"')
RULE_ID=$(echo "${ALERT_JSON}" | jq -r '.rule.id // "N/A"')
AGENT_NAME=$(echo "${ALERT_JSON}" | jq -r '.agent.name // "N/A"')
AGENT_IP=$(echo "${ALERT_JSON}" | jq -r '.agent.ip // "N/A"')
TIMESTAMP=$(echo "${ALERT_JSON}" | jq -r '.timestamp // "N/A"')
SRC_IP=$(echo "${ALERT_JSON}" | jq -r '.data.srcip // "N/A"')

# Set color based on severity
if [[ ${RULE_LEVEL} -ge 12 ]]; then
    COLOR="#FF0000"  # Red - Critical
    EMOJI=":rotating_light:"
elif [[ ${RULE_LEVEL} -ge 8 ]]; then
    COLOR="#FF8C00"  # Orange - High
    EMOJI=":warning:"
elif [[ ${RULE_LEVEL} -ge 5 ]]; then
    COLOR="#FFD700"  # Yellow - Medium
    EMOJI=":large_yellow_circle:"
else
    COLOR="#36A64F"  # Green - Low
    EMOJI=":information_source:"
fi

# Build Slack payload
PAYLOAD=$(cat << EOF
{
  "username": "SentinelCore",
  "icon_emoji": ":shield:",
  "attachments": [
    {
      "color": "${COLOR}",
      "title": "${EMOJI} SentinelCore Alert - Level ${RULE_LEVEL}",
      "text": "${RULE_DESC}",
      "fields": [
        { "title": "Rule ID", "value": "${RULE_ID}", "short": true },
        { "title": "Level", "value": "${RULE_LEVEL}", "short": true },
        { "title": "Agent", "value": "${AGENT_NAME} (${AGENT_IP})", "short": true },
        { "title": "Source IP", "value": "${SRC_IP}", "short": true },
        { "title": "Timestamp", "value": "${TIMESTAMP}", "short": false }
      ],
      "footer": "SentinelCore Security",
      "ts": $(date +%s)
    }
  ]
}
EOF
)

# Send to Slack
curl -s -X POST -H "Content-Type: application/json" -d "${PAYLOAD}" "${WEBHOOK_URL}" >/dev/null 2>&1

exit 0
