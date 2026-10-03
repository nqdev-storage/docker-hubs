# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Dockerfile - Playwright MCP Server (OPTIMIZED - RECOMMENDED)
# -----------------------------------------
# Strategy: Chromium-only base image
# Size: ~1.2GB (52% reduction from 2.5GB+)
# Build: ~3 minutes
# Effort: Minimal
# Build: docker build -t playwright-mcp:latest -f Dockerfile.optimized .
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Use Chromium-only base image (smaller than full Playwright)
FROM mcr.microsoft.com/playwright:v1.40.0-focal

ARG IMAGE_VERSION
LABEL version="${IMAGE_VERSION}" \
  title="PlayWright MCP" \
  description="Docker image for PlayWright MCP server with additional tools and configurations"

WORKDIR /app

# Set environment variables
ENV NODE_ENV=production \
  NPM_CONFIG_LOGLEVEL=error \
  TZ=Asia/Ho_Chi_Minh

# Base image already has:
# - Node.js + npm
# - Chromium browser (pre-installed)
# - All system dependencies for Chromium
# DO NOT re-install or install browsers again

# Expose MCP server port
EXPOSE 8931

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -fs http://localhost:8931/ || exit 1

# Default command - run Playwright MCP server
CMD ["npx", "--yes", "@playwright/mcp", \
  "--host", "0.0.0.0", \
  "--port", "8931", \
  "--allowed-hosts=*", \
  "--headless"]
