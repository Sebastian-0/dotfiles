FROM node:20

ARG CLAUDE_CODE_VERSION=latest
# Remap the built-in `node` user/group to match the host UID/GID so that
# bind-mounts (credentials, workspace) and named-volume writes stay readable
# on both sides. Defaults match the upstream image.
ARG HOST_UID=1000
ARG HOST_GID=1000

# Tools needed at runtime:
#   - iptables/ipset/aggregate/jq/dnsutils/curl: firewall setup
#   - sudo: bootstrap invokes the firewall script as root
#   - git: worktree operations and general use inside the sandbox
#   - python3/pip/pipx/ripgrep: common tooling users want when running scripts
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
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN if [ "$HOST_GID" != "1000" ]; then groupmod -g "$HOST_GID" node; fi \
  && if [ "$HOST_UID" != "1000" ]; then usermod -u "$HOST_UID" node; fi \
  && chown -R node:node /home/node

RUN mkdir -p /workspace/project /workspace/claude-host /home/node/.claude \
  && chown -R node:node /workspace /home/node/.claude

# Give node write access to the npm global prefix (pattern from Anthropic ref).
RUN mkdir -p /usr/local/share/npm-global \
  && chown -R node:node /usr/local/share/npm-global

# Firewall script is owned by root, but `node` needs passwordless sudo to run
# it from bootstrap.sh (same pattern as Anthropic's reference devcontainer).
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
COPY bootstrap.sh     /usr/local/bin/bootstrap.sh
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/bootstrap.sh \
  && printf '%s\n' \
       "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" \
       "node ALL=(root) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /usr/bin/dpkg, /usr/bin/pip, /usr/bin/pip3" \
       > /etc/sudoers.d/node-sandbox \
  && chmod 0440 /etc/sudoers.d/node-sandbox

ENV CLAUDE_CONFIG_DIR=/home/node/.claude
ENV PATH=/usr/local/share/npm-global/bin:$PATH

# Make sure that mirrors are available in the image
RUN apt-get update

USER node
RUN npm config set prefix /usr/local/share/npm-global \
  && npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

WORKDIR /workspace/project
ENTRYPOINT ["/usr/local/bin/bootstrap.sh"]
