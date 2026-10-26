FROM node:22-bookworm-slim

ARG IMAGE_VERSION=dev \
  CLAUDE_CODE_VERSION=latest \
  GIT_USER_NAME="Claude Code" \
  GIT_USER_EMAIL="claude@quyit.id.vn"

LABEL version="${IMAGE_VERSION}" \
  title="Claude Code" \
  description="Docker image for Claude Code Remote Control" \
  maintainer="ClaudeCode <claude@quyit.id.vn>"

# Set environment variables
ENV TZ=Asia/Ho_Chi_Minh \
  NODE_ENV=production \
  NPM_CONFIG_LOGLEVEL=error

# Công cụ cơ bản + Python + Chromium
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  git ca-certificates curl tini ripgrep openssh-client less procps jq unzip \
  python3 python3-dev python3-pip python3-venv build-essential \
  chromium fonts-liberation fonts-noto-color-emoji fonts-noto-cjk \
  && rm -rf /var/lib/apt/lists/*

# Đảm bảo shell mặc định là bash
RUN ln -sf /bin/bash /bin/sh

# Cài Claude Code CLI, LocalTunnel và Bun (cung cấp bun + bunx) toàn cục
RUN npm install -g @anthropic-ai/claude-code localtunnel bun \
  && npm cache clean --force

# Python venv dùng chung (tránh lỗi PEP 668 của Debian 12 khi pip install)
RUN python3 -m venv /opt/venv && chown -R node:node /opt/venv
ENV VIRTUAL_ENV=/opt/venv \
  PATH="/opt/venv/bin:$PATH"

# Thư mục làm việc + thư mục cấu hình (sẽ được mount volume)
RUN mkdir -p /workspace /home/node/.claude \
  && chown -R node:node /workspace /home/node/.claude

# include/ = nội dung được copy vào image theo công dụng, mỗi thư mục con ứng với một đích:
#   include/.claude/             -> /home/node/.claude/            (cấu hình Claude Code global: commands, settings.json, ...)
#   include/claude-memory-hub/   -> /home/node/.claude-memory-hub/ (cấu hình claude-memory-hub, copy sau bước install bên dưới)
# Thêm thư mục mới trong include/ thì thêm một dòng COPY tương ứng.
COPY --chown=node:node include/.claude/ /home/node/.claude/

USER node

# Cấu hình môi trường cho Claude Code và Headless Browser
ENV CLAUDE_CONFIG_DIR=/home/node/.claude \
  CHROME_BIN=/usr/bin/chromium \
  PUPPETEER_SKIP_DOWNLOAD=true \
  PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
  PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

RUN git config --global user.name "${GIT_USER_NAME}" \
  && git config --global user.email "${GIT_USER_EMAIL}" \
  && git config --global --add safe.directory /workspace

# Cài sẵn claude-memory-hub vào ~/.claude (MCP server + hooks trong settings.json + slash command mem-*)
# và ~/.claude-memory-hub (runtime + DB). Cần bun (đã cài ở trên).
RUN bunx claude-memory-hub@latest install \
  && bunx claude-memory-hub status

# Privacy rule cho claude-memory-hub (che secret/đường dẫn nhạy cảm trước khi lưu vào memory.db)
COPY --chown=node:node include/claude-memory-hub/ /home/node/.claude-memory-hub/

WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["claude", "remote-control", "--name", "Docker RC"]
