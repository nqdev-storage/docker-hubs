# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Dockerfile - Playwright MCP Server (OPTIMIZED)
# -----------------------------------------
# Build: docker build -t playwright-mcp:v1.54.2-slim -f Dockerfile.optimized .
# Size: ~1.2GB (vs ~2.5GB+ with multi-browser)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Use Chromium-only base image (smaller than full Playwright)
FROM mcr.microsoft.com/playwright:v1.54.2-chromium-noble

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
