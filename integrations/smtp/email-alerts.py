#!/usr/bin/env python3
"""
SentinelCore - Email Alert Integration
============================================================================
Sends formatted HTML email alerts for high-severity events.
Usage: python3 email-alerts.py <alert_file> <api_key> <hook_url>
============================================================================
"""

import json
import sys
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime

# Configuration
SMTP_SERVER = os.environ.get("SENTINELCORE_SMTP_SERVER", "smtp.SENTINELCORE_DOMAIN")
SMTP_PORT = int(os.environ.get("SENTINELCORE_SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SENTINELCORE_SMTP_USER", "alerts@SENTINELCORE_DOMAIN")
SMTP_PASS = os.environ.get("SENTINELCORE_SMTP_PASS", "")
EMAIL_FROM = os.environ.get("SENTINELCORE_EMAIL_FROM", "alerts@SENTINELCORE_DOMAIN")
EMAIL_TO = os.environ.get("SENTINELCORE_ADMIN_EMAIL", "admin@SENTINELCORE_DOMAIN")
MIN_LEVEL = 10


def parse_alert(alert_file: str) -> dict:
    try:
        with open(alert_file, "r") as f:
            return json.load(f)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def get_severity_color(level: int) -> str:
    if level >= 12:
        return "#dc3545"
    elif level >= 8:
        return "#fd7e14"
    elif level >= 5:
        return "#ffc107"
    return "#28a745"


def build_html_email(alert: dict) -> str:
    rule = alert.get("rule", {})
    agent = alert.get("agent", {})
    data = alert.get("data", {})
    level = rule.get("level", 0)
    color = get_severity_color(level)

    html = f"""
    <html>
    <body style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
            <!-- Header -->
            <div style="background: {color}; padding: 20px; text-align: center;">
                <h1 style="color: white; margin: 0; font-size: 20px;">🛡️ SentinelCore Security Alert</h1>
                <p style="color: rgba(255,255,255,0.9); margin: 5px 0 0;">Level {level} Alert Detected</p>
            </div>

            <!-- Content -->
            <div style="padding: 20px;">
                <h2 style="color: #333; margin-top: 0;">{rule.get('description', 'Security Alert')}</h2>

                <table style="width: 100%; border-collapse: collapse; margin: 15px 0;">
                    <tr style="border-bottom: 1px solid #eee;">
                        <td style="padding: 8px; font-weight: bold; color: #666;">Rule ID</td>
                        <td style="padding: 8px;">{rule.get('id', 'N/A')}</td>
                    </tr>
                    <tr style="border-bottom: 1px solid #eee;">
                        <td style="padding: 8px; font-weight: bold; color: #666;">Agent</td>
                        <td style="padding: 8px;">{agent.get('name', 'N/A')} ({agent.get('ip', 'N/A')})</td>
                    </tr>
                    <tr style="border-bottom: 1px solid #eee;">
                        <td style="padding: 8px; font-weight: bold; color: #666;">Source IP</td>
                        <td style="padding: 8px;">{data.get('srcip', 'N/A')}</td>
                    </tr>
                    <tr style="border-bottom: 1px solid #eee;">
                        <td style="padding: 8px; font-weight: bold; color: #666;">User</td>
                        <td style="padding: 8px;">{data.get('srcuser', 'N/A')}</td>
                    </tr>
                    <tr style="border-bottom: 1px solid #eee;">
                        <td style="padding: 8px; font-weight: bold; color: #666;">Groups</td>
                        <td style="padding: 8px;">{', '.join(rule.get('groups', []))}</td>
                    </tr>
                    <tr>
                        <td style="padding: 8px; font-weight: bold; color: #666;">Timestamp</td>
                        <td style="padding: 8px;">{alert.get('timestamp', 'N/A')}</td>
                    </tr>
                </table>

                <div style="background: #f8f9fa; padding: 12px; border-radius: 4px; margin-top: 15px;">
                    <strong style="color: #666;">Full Log:</strong>
                    <pre style="white-space: pre-wrap; word-wrap: break-word; font-size: 12px; margin: 8px 0 0;">{alert.get('full_log', 'N/A')[:1024]}</pre>
                </div>
            </div>

            <!-- Footer -->
            <div style="background: #f8f9fa; padding: 15px; text-align: center; font-size: 12px; color: #999;">
                SentinelCore Security Monitoring | {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
            </div>
        </div>
    </body>
    </html>
    """
    return html


def send_email(subject: str, html_body: str) -> bool:
    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = EMAIL_FROM
        msg["To"] = EMAIL_TO

        msg.attach(MIMEText(html_body, "html"))

        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            if SMTP_USER and SMTP_PASS:
                server.login(SMTP_USER, SMTP_PASS)
            server.sendmail(EMAIL_FROM, EMAIL_TO.split(","), msg.as_string())

        return True
    except Exception as e:
        print(f"Email send failed: {e}", file=sys.stderr)
        return False


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <alert_file> [api_key] [hook_url]", file=sys.stderr)
        sys.exit(1)

    alert = parse_alert(sys.argv[1])
    rule = alert.get("rule", {})

    if rule.get("level", 0) < MIN_LEVEL:
        sys.exit(0)

    subject = f"[SentinelCore Alert] Level {rule.get('level', 'N/A')} - {rule.get('description', 'Security Alert')}"
    html_body = build_html_email(alert)
    success = send_email(subject, html_body)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
