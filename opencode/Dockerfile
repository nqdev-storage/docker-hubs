# Sử dụng image opencode làm base image
# https://github.com/anomalyco/opencode/pkgs/container/opencode
# FROM ghcr.io/anomalyco/opencode:1.17.18
# FROM ghcr.io/anomalyco/opencode:1.18.33
FROM ghcr.io/anomalyco/opencode:2.0.22

ARG IMAGE_VERSION
LABEL version=""

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
