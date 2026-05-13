FROM ubuntu:24.04

ARG CLAUDE_CODE_VERSION=latest
# Remap the default `ubuntu` user/group to match the host UID/GID so that
# bind-mounts (workspace) and named-volume writes stay readable on both sides.
# ubuntu:24.04 ships with `ubuntu`/`ubuntu` at 1000:1000 already.
ARG HOST_UID=1000
ARG HOST_GID=1000
ARG SANDBOX_USER=ubuntu

ENV DEBIAN_FRONTEND=noninteractive

# Tools needed at runtime:
#   - iptables/ipset/aggregate/jq/dnsutils/curl: firewall setup
#   - sudo: bootstrap invokes the firewall script as root
#   - git: worktree operations and general use inside the sandbox
#   - python3/pip/pipx/ripgrep: common tooling users want when running scripts
#   - nodejs/npm: needed for claude-code; pulled from NodeSource for a newer
#     toolchain than ubuntu:24.04's archive (still apt-managed).
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dnsutils \
        git \
        iptables \
        ipset \
        aggregate \
        iproute2 \
        jq \
        less \
        procps \
        python3 \
        python3-pip \
        pipx \
        ripgrep \
        sudo \
        unzip \
        vim \
        kitty-terminfo \
        gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Remap the runtime user to the host UID/GID. Extracted to a script so project
# overlays that swap the base image entirely can re-run the same logic.
COPY remap-user.sh /usr/local/bin/remap-user.sh
RUN chmod +x /usr/local/bin/remap-user.sh \
    && /usr/local/bin/remap-user.sh "$SANDBOX_USER" "$HOST_UID" "$HOST_GID"

RUN mkdir -p /workspace/project /workspace/claude-host "/home/$SANDBOX_USER/.claude" \
    && chown -R "$SANDBOX_USER:$SANDBOX_USER" /workspace "/home/$SANDBOX_USER/.claude"

# npm global prefix owned by the runtime user (pattern from Anthropic ref).
RUN mkdir -p /usr/local/share/npm-global \
    && chown -R "$SANDBOX_USER:$SANDBOX_USER" /usr/local/share/npm-global

# Firewall script is owned by root, but the runtime user needs passwordless
# sudo to run it from bootstrap.sh (same pattern as Anthropic's reference
# devcontainer).
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
COPY bootstrap.sh /usr/local/bin/bootstrap.sh
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/bootstrap.sh \
    && printf '%s\n' \
        "$SANDBOX_USER ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" \
        "$SANDBOX_USER ALL=(root) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /usr/bin/dpkg, /usr/bin/pip, /usr/bin/pip3" \
        > /etc/sudoers.d/sandbox-user \
    && chmod 0440 /etc/sudoers.d/sandbox-user

ENV CLAUDE_CONFIG_DIR=/home/${SANDBOX_USER}/.claude
ENV PATH=/usr/local/share/npm-global/bin:$PATH
ENV SANDBOX_USER=${SANDBOX_USER}

# Make sure that mirrors are available in the image
RUN apt-get update

USER ${SANDBOX_USER}
RUN npm config set prefix /usr/local/share/npm-global \
    && npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

WORKDIR /workspace/project
ENTRYPOINT ["/usr/local/bin/bootstrap.sh"]
