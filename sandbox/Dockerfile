# The base image is supplied by launch.sh: either ubuntu:24.04 by default, or
# whatever .claudesafe/Dockerfile / .claudesafe/base-image.sh produces. This
# Dockerfile is the claudesafe *layer* -- it bolts node/claude/firewall/sudoers
# onto whatever base it gets, and remaps the `ubuntu` user to the host UID/GID.
# Assumption: BASE is Debian/Ubuntu-derived and already has a `ubuntu` user.
ARG BASE=ubuntu:24.04
FROM ${BASE}

ARG CLAUDE_CODE_VERSION=latest
ARG HOST_UID=1000
ARG HOST_GID=1000
ARG SANDBOX_USER=ubuntu

ENV DEBIAN_FRONTEND=noninteractive

USER root

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
        ssh \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Remap the runtime user to the host UID/GID. Extracted to a script so project
# overlays that swap the base image entirely can re-run the same logic.
COPY remap-user.sh /usr/local/bin/remap-user.sh
RUN chmod +x /usr/local/bin/remap-user.sh \
    && /usr/local/bin/remap-user.sh "$SANDBOX_USER" "$HOST_UID" "$HOST_GID"

RUN mkdir -p /workspace/project /workspace/claude-host \
        "/home/$SANDBOX_USER/.claude" \
        "/home/$SANDBOX_USER/.config/gh" \
    && chown -R "$SANDBOX_USER:$SANDBOX_USER" /workspace \
        "/home/$SANDBOX_USER/.claude" \
        "/home/$SANDBOX_USER/.config"

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
CMD ["/usr/local/bin/bootstrap.sh"]
