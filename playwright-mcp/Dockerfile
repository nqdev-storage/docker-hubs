# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Dockerfile - Playwright MCP Server
# -----------------------------------------
# Build: docker build -t playwright-mcp:v1.54.2 .
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

FROM mcr.microsoft.com/playwright:v1.54.2-noble

# Set working directory
WORKDIR /app

# Set environment variables
ENV NODE_ENV=production \
    NPM_CONFIG_LOGLEVEL=warn \
    TZ=Asia/Ho_Chi_Minh

# Install Playwright browsers (Chrome)
RUN npx -y playwright install chrome && \
    npx -y playwright install-deps chrome

# Expose MCP server port
EXPOSE 8931

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8931/ || exit 1

# Default command - run Playwright MCP server
CMD ["npx", "-y", "@playwright/mcp", \
     "--host", "0.0.0.0", \
     "--port", "8931", \
     "--allowed-hosts=*", \
     "--headless", \
     "--caps=network,storage,testing,vision,devtools"]
