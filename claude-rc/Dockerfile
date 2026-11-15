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
  python3 python3-pip python3-venv \
  chromium fonts-liberation fonts-noto-color-emoji \
  && rm -rf /var/lib/apt/lists/*

# [nqdev] Không cài sẵn Java/Maven để giảm kích thước image; cài khi cần bằng `10-install-java-maven.sh` (xem README).
# JAVA_HOME/MAVEN_HOME/PATH trỏ sẵn tới thư mục script cài vào (thuộc user node) nên cài xong dùng được ngay, không cần sửa PATH
# /opt/scripts đưa vào PATH để gọi script theo tên
# INSTALL_JAVA_MAVEN=true thì 00-entrypoint.sh tự gọi 10-install-java-maven.sh lúc khởi động (mặc định false)
ENV INSTALL_JAVA_MAVEN=false \
  JAVA_HOME=/home/node/.local/opt/java \
  MAVEN_HOME=/home/node/.local/opt/maven \
  PATH="/opt/scripts:/home/node/.local/opt/java/bin:/home/node/.local/opt/maven/bin:$PATH"

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
RUN mkdir -p /workspace /home/node/.claude /home/node/.local/opt \
  && chown -R node:node /workspace /home/node/.claude /home/node/.local

# include/ = nội dung được copy vào image theo công dụng, mỗi thư mục con ứng với một đích:
#   include/.claude/             -> /home/node/.claude/            (cấu hình Claude Code global: commands, settings.json, ...)
#   include/claude-memory-hub/   -> /home/node/.claude-memory-hub/ (cấu hình claude-memory-hub, copy sau bước install bên dưới)
# Thêm thư mục mới trong include/ thì thêm một dòng COPY tương ứng.
COPY --chown=node:node include/.claude/ /home/node/.claude/

# scripts/ (ngoài include/) = script chạy hoặc cần để chạy trong image -> /opt/scripts (đã có trong PATH), vd 10-install-java-maven.sh
COPY --chmod=755 scripts/ /opt/scripts/

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

# [nqdev] Context7 (MCP remote qua HTTP, không chạy gì trong container) để Claude lấy tài liệu thư viện mới nhất, tránh sinh code theo API cũ
RUN claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp

# Cài sẵn claude-memory-hub vào ~/.claude (MCP server + hooks trong settings.json + slash command mem-*)
# và ~/.claude-memory-hub (runtime + DB). Cần bun (đã cài ở trên).
# [nqdev] Xóa cache bun ngay trong cùng layer (~410MB: onnxruntime/huggingface dành cho embeddings, mặc định không dùng); runtime đã nằm ở ~/.claude-memory-hub
RUN bunx claude-memory-hub@latest install \
  && bunx claude-memory-hub status \
  && rm -rf /home/node/.bun/install/cache

# Privacy rule cho claude-memory-hub (che secret/đường dẫn nhạy cảm trước khi lưu vào memory.db)
COPY --chown=node:node include/claude-memory-hub/ /home/node/.claude-memory-hub/

# [nqdev] Lưu bản gốc của ~/.claude và ~/.claude-memory-hub ngoài các đường dẫn bị bind mount; 00-entrypoint.sh chép bổ sung vào
# thư mục đã mount (không ghi đè) mỗi lần khởi động, để settings.json/hook/runtime không bị mất khi mount thư mục host trống
RUN mkdir -p /home/node/.image-defaults \
  && cp -a /home/node/.claude /home/node/.image-defaults/claude \
  && cp -a /home/node/.claude-memory-hub /home/node/.image-defaults/claude-memory-hub

WORKDIR /workspace

# tini giữ vai trò PID 1, 00-entrypoint.sh khởi tạo dữ liệu rồi exec CMD
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/scripts/00-entrypoint.sh"]
CMD ["claude", "remote-control", "--name", "Docker RC"]
