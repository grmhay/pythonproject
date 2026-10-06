FROM node:24-bookworm

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

# UID/GID alignment so bind-mounted files share ownership with the host user.
# The target GID may already exist in the base image (100 is "users" on
# Debian), in which case the node group keeps its own GID and the agent user
# simply joins the existing one — renaming it would fail.
ARG AGENT_UID=1000
ARG AGENT_GID=1000
RUN { getent group "$AGENT_GID" >/dev/null || groupmod -g "$AGENT_GID" node; } \
    && usermod -u "$AGENT_UID" -g "$AGENT_GID" -d /home/agent -m -l agent node
USER ${AGENT_UID}:${AGENT_GID}

# Claude Code CLI
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/agent/.local/bin:$PATH"

# Pre-accept the workspace trust dialog. Claude Code ignores the repo's
# .claude/settings.json permissions in an untrusted workspace, and the dialog
# can only be accepted interactively — which nothing in a sandbox can do, so
# without this every agent runs without the project's permission allowlist.
ARG AGENT_WORKSPACE=/home/agent/workspace
RUN printf '{"projects":{"%s":{"hasTrustDialogAccepted":true}}}\n' \
      "$AGENT_WORKSPACE" > /home/agent/.claude.json

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
