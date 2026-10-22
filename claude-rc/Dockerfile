FROM node:22-bookworm-slim

ARG IMAGE_VERSION
LABEL version="${IMAGE_VERSION}" \
  title="Claude Code" \
  description="Docker image for Claude Code Remote Control" \
  maintainer="OpenCode <opencode@quyit.id.vn>"

# Set environment variables
ENV TZ=Asia/Ho_Chi_Minh \
  NODE_ENV=production \
  NPM_CONFIG_LOGLEVEL=error

# Công cụ mà Claude Code hay dùng khi làm việc với code
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  git ca-certificates curl tini ripgrep openssh-client less procps \
  && rm -rf /var/lib/apt/lists/*

# Cập nhật và cài đặt các công cụ cần thiết (Git, Python, pip)
# RUN apk update && \
#   apk add --no-cache \
#   python3 \
#   python3-dev \
#   py3-pip \
#   git \
#   bash \
#   util-linux \
#   coreutils \
#   curl \
#   chromium \
#   nodejs \
#   npm && \
#   rm -rf /var/cache/apk/*

# đảm bảo shell tồn tại
RUN ln -sf /bin/bash /bin/sh

# Cài Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code \
  && npm cache clean --force

# Thư mục làm việc + thư mục cấu hình (sẽ được mount volume)
RUN mkdir -p /workspace /home/node/.claude \
  && chown -R node:node /workspace /home/node/.claude

USER node

# Gom cả .claude.json và .credentials.json vào 1 thư mục để persist bằng 1 volume
ENV CLAUDE_CONFIG_DIR=/home/node/.claude
# KHÔNG đặt CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC / DISABLE_GROWTHBOOK / ANTHROPIC_API_KEY
# vì Remote Control sẽ không chạy được.

WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["claude", "remote-control", "--name", "Docker RC"]
