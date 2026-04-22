#!/bin/bash
# Adapted from anthropics/claude-code/.devcontainer/init-firewall.sh.
# Differences:
#   - Domain allowlist is read from /etc/allowlist.txt (mounted from the host)
#     so it can be edited without rebuilding the image.
#   - Keeps a small hardcoded baseline (Anthropic API + GitHub meta ranges)
#     so the container is usable even if the allowlist file is missing.
set -euo pipefail
IFS=$'\n\t'

ALLOWLIST_FILE="${ALLOWLIST_FILE:-/etc/allowlist.txt}"

# 1. Save Docker's internal DNS NAT rules before we flush.
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2> /dev/null || true

if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2> /dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2> /dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
fi

# DNS + localhost + SSH (SSH is allowed so that git-over-ssh works; remove
# the two SSH lines if you want to block it).
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

ipset create allowed-domains hash:net

# GitHub IP ranges (dynamic; GitHub publishes them via their meta endpoint).
echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -fsS https://api.github.com/meta || true)
if [ -n "$gh_ranges" ] && echo "$gh_ranges" | jq -e '.web and .api and .git' > /dev/null; then
    while read -r cidr; do
        if [[ "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
            ipset add allowed-domains "$cidr"
        fi
    done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q 2> /dev/null || echo "$gh_ranges" | jq -r '(.web + .api + .git)[]')
else
    echo "WARNING: could not fetch GitHub IP ranges; continuing without them."
fi

# Baseline domains (always allowed even if allowlist.txt is missing) plus any
# domains listed in $ALLOWLIST_FILE (one per line, '#' for comments).
baseline=(
    "api.anthropic.com"
    "statsig.anthropic.com"
    "statsig.com"
    "sentry.io"
    "registry.npmjs.org"
)

extra=()
if [ -f "$ALLOWLIST_FILE" ]; then
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        [ -n "$line" ] && extra+=("$line")
    done < "$ALLOWLIST_FILE"
    echo "Loaded ${#extra[@]} extra domains from $ALLOWLIST_FILE"
else
    echo "No $ALLOWLIST_FILE found; using baseline only."
fi

for domain in "${baseline[@]}" "${extra[@]}"; do
    echo "Resolving $domain..."
    ips=$(dig +noall +answer +time=3 +tries=1 A "$domain" | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        echo "WARNING: could not resolve $domain; skipping."
        continue
    fi
    while read -r ip; do
        if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            ipset add allowed-domains "$ip" 2> /dev/null || true
        fi
    done < <(echo "$ips")
done

# Let container talk to its own host network (docker bridge gateway).
HOST_IP=$(ip route | awk '/default/ {print $3; exit}')
if [ -n "$HOST_IP" ]; then
    HOST_NETWORK=$(echo "$HOST_IP" | sed 's/\.[0-9]*$/.0\/24/')
    iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
    iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT
fi

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "Firewall configuration complete"

# Quick sanity check: confirm we're blocking the obvious stuff and allowing
# api.anthropic.com (the one thing that MUST work for Claude to talk to its API).
if curl --connect-timeout 5 -sS https://example.com > /dev/null 2>&1; then
    echo "ERROR: firewall verification failed -- reached https://example.com"
    exit 1
fi
if ! curl --connect-timeout 5 -sS https://api.anthropic.com > /dev/null 2>&1; then
    echo "ERROR: firewall verification failed -- could not reach https://api.anthropic.com"
    exit 1
fi
echo "Firewall verification passed"
