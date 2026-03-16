#!/usr/bin/env python3
"""
SentinelCore - Prometheus Metrics Exporter
============================================================================
Exports Wazuh manager metrics for Prometheus scraping.
Exposes metrics on port 9101 by default.
Usage: python3 wazuh-exporter.py [--port PORT] [--interval SECONDS]
============================================================================
"""

import json
import subprocess
import time
import os
import sys
import argparse
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.request import urlopen, Request
from urllib.error import URLError
import ssl

# Configuration
WAZUH_API_URL = f"https://{os.environ.get('SENTINELCORE_MANAGER_IP', 'localhost')}:55000"
API_USER = os.environ.get("SENTINELCORE_API_USER", "wazuh-wui")
API_PASS = os.environ.get("SENTINELCORE_API_PASS", "SENTINELCORE_AUTH_PASS")
EXPORTER_PORT = 9101
SCRAPE_INTERVAL = 30

# Metrics storage
metrics = {}


def get_api_token() -> str:
    """Get JWT token from Wazuh API."""
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        import base64
        credentials = base64.b64encode(f"{API_USER}:{API_PASS}".encode()).decode()
        req = Request(
            f"{WAZUH_API_URL}/security/user/authenticate",
            headers={"Authorization": f"Basic {credentials}"},
            method="POST",
        )
        with urlopen(req, context=ctx, timeout=10) as resp:
            data = json.loads(resp.read())
            return data.get("data", {}).get("token", "")
    except Exception as e:
        print(f"Auth error: {e}", file=sys.stderr)
        return ""


def api_request(endpoint: str, token: str) -> dict:
    """Make authenticated API request."""
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        req = Request(
            f"{WAZUH_API_URL}{endpoint}",
            headers={"Authorization": f"Bearer {token}"},
        )
        with urlopen(req, context=ctx, timeout=10) as resp:
            return json.loads(resp.read())
    except Exception as e:
        print(f"API error ({endpoint}): {e}", file=sys.stderr)
        return {}


def collect_metrics():
    """Collect all metrics from Wazuh API."""
    global metrics
    token = get_api_token()
    if not token:
        metrics["sentinelcore_api_up"] = 0
        return

    metrics["sentinelcore_api_up"] = 1

    # Manager info
    manager_info = api_request("/manager/info", token)
    if manager_info.get("data"):
        info = manager_info["data"].get("affected_items", [{}])[0]
        metrics["sentinelcore_manager_version"] = 1  # gauge with label

    # Agent statistics
    agents_summary = api_request("/agents/summary/status", token)
    if agents_summary.get("data"):
        connection = agents_summary["data"].get("connection", {})
        metrics["sentinelcore_agents_active"] = connection.get("active", 0)
        metrics["sentinelcore_agents_disconnected"] = connection.get("disconnected", 0)
        metrics["sentinelcore_agents_pending"] = connection.get("pending", 0)
        metrics["sentinelcore_agents_never_connected"] = connection.get("never_connected", 0)
        metrics["sentinelcore_agents_total"] = connection.get("total", 0)

    # Manager stats
    manager_stats = api_request("/manager/stats", token)
    if manager_stats.get("data"):
        items = manager_stats["data"].get("affected_items", [])
        if items:
            latest = items[-1] if items else {}
            metrics["sentinelcore_alerts_total"] = latest.get("alerts", [{}])[-1].get("totalAlerts", 0) if latest.get("alerts") else 0
            metrics["sentinelcore_events_received"] = latest.get("events", 0)
            metrics["sentinelcore_syscheck_events"] = latest.get("syscheck", 0)
            metrics["sentinelcore_firewall_events"] = latest.get("firewall", 0)

    # Cluster status
    cluster_status = api_request("/cluster/status", token)
    if cluster_status.get("data"):
        metrics["sentinelcore_cluster_enabled"] = 1 if cluster_status["data"].get("enabled") == "yes" else 0
        metrics["sentinelcore_cluster_running"] = 1 if cluster_status["data"].get("running") == "yes" else 0

    # Rules and decoders count
    rules = api_request("/rules?limit=1", token)
    if rules.get("data"):
        metrics["sentinelcore_rules_total"] = rules["data"].get("total_affected_items", 0)

    decoders = api_request("/decoders?limit=1", token)
    if decoders.get("data"):
        metrics["sentinelcore_decoders_total"] = decoders["data"].get("total_affected_items", 0)

    metrics["sentinelcore_last_scrape_timestamp"] = int(time.time())


def format_metrics() -> str:
    """Format metrics in Prometheus exposition format."""
    lines = [
        "# HELP sentinelcore_api_up Whether the SentinelCore API is reachable",
        "# TYPE sentinelcore_api_up gauge",
        "# HELP sentinelcore_agents_active Number of active agents",
        "# TYPE sentinelcore_agents_active gauge",
        "# HELP sentinelcore_agents_disconnected Number of disconnected agents",
        "# TYPE sentinelcore_agents_disconnected gauge",
        "# HELP sentinelcore_agents_total Total number of agents",
        "# TYPE sentinelcore_agents_total gauge",
        "# HELP sentinelcore_alerts_total Total alerts in last interval",
        "# TYPE sentinelcore_alerts_total gauge",
        "# HELP sentinelcore_cluster_enabled Whether clustering is enabled",
        "# TYPE sentinelcore_cluster_enabled gauge",
        "# HELP sentinelcore_rules_total Total detection rules loaded",
        "# TYPE sentinelcore_rules_total gauge",
        "# HELP sentinelcore_decoders_total Total decoders loaded",
        "# TYPE sentinelcore_decoders_total gauge",
        "",
    ]

    for key, value in sorted(metrics.items()):
        if isinstance(value, (int, float)):
            lines.append(f"{key} {value}")

    return "\n".join(lines) + "\n"


class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            body = format_metrics().encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # Suppress access logs


def main():
    parser = argparse.ArgumentParser(description="SentinelCore Prometheus Exporter")
    parser.add_argument("--port", type=int, default=EXPORTER_PORT, help="Exporter port")
    parser.add_argument("--interval", type=int, default=SCRAPE_INTERVAL, help="Scrape interval (seconds)")
    args = parser.parse_args()

    print(f"SentinelCore Exporter starting on port {args.port}")
    print(f"Scrape interval: {args.interval}s")
    print(f"Metrics endpoint: http://0.0.0.0:{args.port}/metrics")

    # Initial collection
    collect_metrics()

    # Start HTTP server in background
    import threading

    server = HTTPServer(("0.0.0.0", args.port), MetricsHandler)
    server_thread = threading.Thread(target=server.serve_forever)
    server_thread.daemon = True
    server_thread.start()

    # Collection loop
    while True:
        time.sleep(args.interval)
        try:
            collect_metrics()
        except Exception as e:
            print(f"Collection error: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
