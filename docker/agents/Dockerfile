# ============================================================================
# SentinelCore - Docker Agent Image
# ============================================================================
# Custom Wazuh agent image with SentinelCore branding and configuration.
# Build: docker build -t sentinelcore-agent .
# ============================================================================

FROM ubuntu:22.04

ARG WAZUH_VERSION=4.9.0

LABEL maintainer="SentinelCore Security"
LABEL description="SentinelCore Wazuh Agent"
LABEL version="${WAZUH_VERSION}"

ENV DEBIAN_FRONTEND=noninteractive
ENV WAZUH_VERSION=${WAZUH_VERSION}

# Install dependencies
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
    curl \
    apt-transport-https \
    gnupg2 \
    procps \
    iproute2 \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Add Wazuh repository
RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | \
    gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import 2>/dev/null && \
    chmod 644 /usr/share/keyrings/wazuh.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
    > /etc/apt/sources.list.d/wazuh.list

# Install Wazuh agent
RUN apt-get update -qq && \
    apt-get install -y -qq wazuh-agent=${WAZUH_VERSION}-1 && \
    rm -rf /var/lib/apt/lists/*

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy custom config (optional - will be applied by entrypoint if present)
COPY ossec.conf /opt/sentinelcore/ossec.conf

ENTRYPOINT ["/entrypoint.sh"]
