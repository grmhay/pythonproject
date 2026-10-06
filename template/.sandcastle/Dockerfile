FROM node:22-bookworm

RUN apt-get update && apt-get install -y \
  curl \
  git \
  jq \
  python3 \
  python3-pip \
  python3-venv \
  && rm -rf /var/lib/apt/lists/*

# gh CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# UID/GID alignment so bind-mounted files share ownership with the host user
ARG AGENT_UID=1000
ARG AGENT_GID=1000
RUN groupmod -g $AGENT_GID node \
    && usermod -u $AGENT_UID -g $AGENT_GID -d /home/agent -m -l agent node
USER ${AGENT_UID}:${AGENT_GID}

# Claude Code CLI
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/agent/.local/bin:$PATH"

# Python dev tools (user install to stay in agent home)
# All nox sessions use python=False and call tools as external processes,
# so mypy/pytest/ruff must be on PATH — not just available to nox venvs.
RUN pip install --user --no-cache-dir --break-system-packages \
    mypy nox pytest ruff

# taplo has no pip package — install the pre-built binary
RUN curl -fsSL https://github.com/tamasfe/taplo/releases/latest/download/taplo-linux-x86_64.gz \
    | gunzip > /home/agent/.local/bin/taplo \
    && chmod +x /home/agent/.local/bin/taplo

WORKDIR /home/agent

ENTRYPOINT ["sleep", "infinity"]
