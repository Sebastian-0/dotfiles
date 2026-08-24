#!/bin/bash
# Adapted from anthropics/claude-code/.devcontainer/init-firewall.sh.
# Differences:
#   - Domain allowlist is read from /etc/allowlist.txt (mounted from the host)
#     so it can be edited without rebuilding the image.
#   - Keeps a small hardcoded baseline (Anthropic API + GitHub meta ranges)
#     so the container is usable even if the allowlist file is missing.
#   - SANDBOX_STRICT=1 drops everything but the baseline: no allowlist, no
#     GitHub ranges, no outbound SSH, no host network, DNS only to the
#     container's own resolvers, and IPv6 shut off.
set -euo pipefail
IFS=$'\n\t'

LOG_PREFIX=firewall
. /usr/local/lib/log.sh

ALLOWLIST_FILE="${ALLOWLIST_FILE:-/etc/allowlist.txt}"
STRICT="${SANDBOX_STRICT:-0}"

# DNS to an arbitrary server is itself a way to send data out, so strict mode
# pins it to the resolvers the container is configured to use.
allow_strict_dns() {
    local resolvers ns
    resolvers="$(awk '$1 == "nameserver" {print $2}' /etc/resolv.conf 2> /dev/null || true)"
    if [ -z "$resolvers" ]; then
        log_warn "no nameserver in /etc/resolv.conf; allowing DNS to any host"
        iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
        iptables -A INPUT -p udp --sport 53 -j ACCEPT
        return
    fi
    while read -r ns; do
        # Skip IPv6 resolvers -- iptables is v4-only.
        case "$ns" in
            "" | *[!0-9.]*) continue ;;
        esac
        log_info "allowing DNS to $ns"
        iptables -A OUTPUT -p udp -d "$ns" --dport 53 -j ACCEPT
        iptables -A OUTPUT -p tcp -d "$ns" --dport 53 -j ACCEPT
    done < <(printf '%s\n' "$resolvers")
}

# The rules here are IPv4-only, so an IPv6-enabled network would otherwise be
# an unfiltered way out.
block_ipv6() {
    if ! ip6tables -L -n > /dev/null 2>&1; then
        log_warn "ip6tables unavailable; IPv6 left unfiltered"
        return
    fi
    ip6tables -F
    ip6tables -A INPUT -i lo -j ACCEPT
    ip6tables -A OUTPUT -o lo -j ACCEPT
    ip6tables -P INPUT DROP
    ip6tables -P FORWARD DROP
    ip6tables -P OUTPUT DROP
}

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
    log_info "restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2> /dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2> /dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
fi

# DNS + localhost + SSH (SSH is allowed so that git-over-ssh works; remove
# the two SSH lines if you want to block it). Strict mode allows neither --
# SSH reaches any host, and Claude Code never needs it.
if [ "$STRICT" = "1" ]; then
    allow_strict_dns
else
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -p udp --sport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
fi
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

ipset create allowed-domains hash:net

# GitHub IP ranges (dynamic; GitHub publishes them via their meta endpoint).
if [ "$STRICT" = "1" ]; then
    log_info "strict mode -- skipping GitHub IP ranges"
else
    log_info "fetching GitHub IP ranges..."
    gh_ranges=$(curl -fsS https://api.github.com/meta || true)
    if [ -n "$gh_ranges" ] && echo "$gh_ranges" | jq -e '.web and .api and .git' > /dev/null; then
        while read -r cidr; do
            if [[ "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
                ipset add allowed-domains "$cidr"
            fi
        done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q 2> /dev/null || echo "$gh_ranges" | jq -r '(.web + .api + .git)[]')
    else
        log_warn "could not fetch GitHub IP ranges; continuing without them"
    fi
fi

# Baseline domains: what Claude Code itself talks to (API, OAuth login,
# telemetry, the registry it updates from). In strict mode, the only ones
# allowed; otherwise $ALLOWLIST_FILE adds to them.
baseline=(
    "api.anthropic.com"
    "console.anthropic.com"
    "claude.ai"
    "statsig.anthropic.com"
    "statsig.com"
    "sentry.io"
    "registry.npmjs.org"
)

extra=()
if [ "$STRICT" = "1" ]; then
    log_info "strict mode -- ignoring $ALLOWLIST_FILE"
elif [ -f "$ALLOWLIST_FILE" ]; then
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        [ -n "$line" ] && extra+=("$line")
    done < "$ALLOWLIST_FILE"
    log_info "loaded ${#extra[@]} extra domains from $ALLOWLIST_FILE"
else
    log_warn "no $ALLOWLIST_FILE found; using baseline only"
fi

for domain in "${baseline[@]}" "${extra[@]}"; do
    log_info "resolving $domain..."
    ips=$(dig +noall +answer +time=3 +tries=1 A "$domain" | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        log_warn "could not resolve $domain; skipping"
        continue
    fi
    while read -r ip; do
        if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            ipset add allowed-domains "$ip" 2> /dev/null || true
        fi
    done < <(echo "$ips")
done

# Let container talk to its own host network (docker bridge gateway). Strict
# mode leaves it out; Claude Code needs nothing there.
if [ "$STRICT" = "1" ]; then
    log_info "strict mode -- not allowing the host network"
else
    HOST_IP=$(ip route | awk '/default/ {print $3; exit}')
    if [ -n "$HOST_IP" ]; then
        HOST_NETWORK=$(echo "$HOST_IP" | sed 's/\.[0-9]*$/.0\/24/')
        iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
        iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT
    fi
fi

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

if [ "$STRICT" = "1" ]; then
    block_ipv6
fi

log_info "firewall configuration complete"

# Quick sanity check: confirm we're blocking the obvious stuff and allowing
# api.anthropic.com (the one thing that MUST work for Claude to talk to its API).
if curl --connect-timeout 5 -sS https://example.com > /dev/null 2>&1; then
    log_error "firewall verification failed -- reached https://example.com"
    exit 1
fi
if ! curl --connect-timeout 5 -sS https://api.anthropic.com > /dev/null 2>&1; then
    log_error "firewall verification failed -- could not reach https://api.anthropic.com"
    exit 1
fi
# github.com is allowed in every non-strict run (the meta ranges), so reaching
# it means the strict path did not take effect.
if [ "$STRICT" = "1" ] && curl --connect-timeout 5 -sS https://github.com > /dev/null 2>&1; then
    log_error "strict mode verification failed -- reached https://github.com"
    exit 1
fi
log_info "firewall verification passed"
