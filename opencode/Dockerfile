# Sử dụng image opencode làm base image
# https://github.com/anomalyco/opencode/pkgs/container/opencode
# FROM ghcr.io/anomalyco/opencode:1.17.18
# FROM ghcr.io/anomalyco/opencode:1.18.33
FROM ghcr.io/anomalyco/opencode:2.0.22

ARG IMAGE_VERSION
LABEL version="${IMAGE_VERSION}"

# Fix: Polyfill crypto.randomUUID for compatibility with isolated JS contexts (upload/context)
COPY ./opencode/preload/ /opt/opencode-preload/
ENV NODE_OPTIONS="--require /opt/opencode-preload/index.js"

# Cập nhật và cài đặt các công cụ cần thiết (Git, Python, pip)
RUN apk update && \
  apk add --no-cache \
  python3 \
  python3-dev \
  py3-pip \
  git \
  bash \
  util-linux \
  coreutils \
  curl \
  chromium \
  nodejs \
  npm && \
  rm -rf /var/cache/apk/*

# đảm bảo shell tồn tại
RUN ln -sf /bin/bash /bin/sh

# Cài Playwright MCP globally (optional nhưng giúp cache nhanh hơn)
# RUN npm install -g @playwright/mcp@latest

# Tạo thư mục config opencode (tuỳ image thực tế)
RUN mkdir -p /root/.config/opencode

# Ghi file MCP config
RUN cat <<EOF > /root/.config/opencode/mcp.json
{
  "playwright": {
    "type": "local",
    "enabled": true,
    "command": [
      "npx",
      "-y",
      "@playwright/mcp@latest",
      "--browser=chromium",
      "--headless",
      "--caps=network,storage,testing,vision,devtools"
    ]
  }
}
EOF

# Kiểm tra version (debug build time)
RUN node --version && npm --version && python3 --version && git --version

# Đảm bảo lệnh 'opencode' được gọi khi container chạy
ENTRYPOINT ["opencode"]
