# Docker Optimization Guide - Playwright MCP Server

## 📊 Image Size Comparison

| Variant | Base Image | Size | Build Time | Runtime Memory | Notes |
|---------|-----------|------|-----------|----------------|-------|
| **Original** | `playwright:v1.54.2-noble` | ~2.5GB+ | ~5 min | 512MB+ | All browsers (Chrome, Firefox, WebKit) |
| **Optimized** | `playwright:v1.54.2-chromium-noble` | ~1.2GB | ~3 min | 256MB | Chromium only |
| **Ultra-Slim** | `node:22-bookworm-slim` | ~800MB | ~8 min | 180MB | Install only Chromium |

---

## 🎯 Optimization Strategies

### 1️⃣ **Use Chromium-only Base Image** (Recommended)
```dockerfile
# ❌ Original (2.5GB+)
FROM mcr.microsoft.com/playwright:v1.54.2-noble

# ✅ Optimized (1.2GB)
FROM mcr.microsoft.com/playwright:v1.54.2-chromium-noble
```

**Benefits:**
- Saves ~1.3GB by removing Firefox & WebKit
- Pre-built system dependencies
- No redundant installations
- Faster startup time

**Drawback:**
- Only Chromium available (usually sufficient for most MCP use cases)

---

### 2️⃣ **Remove Redundant Browser Installations**
```dockerfile
# ❌ Original Dockerfile
RUN npx -y playwright install chrome && \
    npx -y playwright install-deps chrome

# ✅ Correct (base image already has it)
# Just use it directly, no installation needed
```

**Why:**
- `chromium-noble` base image includes:
  - Node.js + npm
  - Chromium browser (fully installed)
  - All required system dependencies
  - No need to re-install

---

### 3️⃣ **Optimize Layer Caching**
```dockerfile
# ❌ Bad order (loses cache on any change)
COPY . .
RUN npm install
RUN npm run build

# ✅ Better order (caches dependencies)
COPY package*.json ./
RUN npm ci --only=production --verbose=false
COPY . .
RUN npm run build
```

**Principle:**
- Put stable layers first
- Volatile changes last
- Improves build speed for iterations

---

### 4️⃣ **Minimize npm Cache & Temp Files**

```dockerfile
# Before: npm installs keep cache (~50-100MB)
RUN npm install

# After: Clean cache during install
RUN npm ci --only=production && \
    npm cache clean --force && \
    rm -rf /usr/local/share/.cache/pip

# Even better: Use multi-stage
FROM node:22-bookworm-slim AS builder
RUN npm ci
FROM node:22-bookworm-slim
COPY --from=builder /app/node_modules ./node_modules
```

**Saves:** 50-100MB per install

---

### 5️⃣ **Use Minimal Base Images**

```dockerfile
# ❌ Large base images
FROM node:22-bullseye           # 910MB
FROM node:22-buster             # 830MB
FROM ubuntu:22.04               # 77MB

# ✅ Minimal options
FROM node:22-bookworm-slim      # 280MB
FROM node:22-alpine             # 180MB (but limited packages)
```

**Recommendation:**
- Use `node:22-bookworm-slim` for balance of size & compatibility
- Use `node:22-alpine` only if packages are available

---

### 6️⃣ **Optimize .dockerignore**

```dockerignore
# Reduce build context (what gets sent to Docker daemon)
.git                # ~100MB+ in large repos
node_modules        # Don't copy, rebuild in container
.github
docs
tests
coverage
dist
build
```

**Impact:** 
- Smaller build context = faster upload to Docker daemon
- Can save 100MB-1GB depending on project

---

## 🚀 Step-by-Step Implementation

### Option A: Quick Fix (Estimated savings: 1.3GB)
```bash
# 1. Replace Dockerfile with optimized version
cp Dockerfile.optimized Dockerfile

# 2. Rebuild
docker-compose down -v --rmi all
docker-compose build

# 3. Verify
docker images | grep playwright-mcp
# Should see ~1.2GB instead of 2.5GB+
```

### Option B: Ultra-Slim (Estimated savings: 1.7GB, longer first build)
```bash
# 1. Use ultra-slim Dockerfile
cp Dockerfile.ultra-slim Dockerfile

# 2. Use optimized docker-compose
cp docker-compose.optimized.yml docker-compose.yml

# 3. Rebuild (takes ~8 min first time)
docker-compose build

# 4. Verify size
docker images | grep playwright-mcp
# Should see ~800MB
```

---

## ⚡ Additional Optimization Tips

### 1. **Use BuildKit for Faster Builds**
```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1
docker build -t playwright-mcp:v1.54.2 .
```

### 2. **Layer Caching with .dockerignore**
```dockerfile
# Stable: Copy only what's needed early
COPY package*.json ./
RUN npm ci --only=production

# Volatile: Copy rest later
COPY . .
```

### 3. **Reduce Runtime Memory**
```yaml
# Original: 2GB limit + 512MB reservation
# Optimized: 1.5GB limit + 256MB reservation
deploy:
  resources:
    limits:
      memory: "1.5G"
    reservations:
      memory: "256M"
```

### 4. **Reduce Shared Memory for Single Browser**
```yaml
# Original: 2GB shm_size (for multi-browser)
# Optimized: 1GB shm_size (Chromium only)
shm_size: 1gb
```

### 5. **Compress Docker Logs**
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "5m"      # Reduced from 10m
    max-file: "2"       # Reduced from 3
```

---

## 📈 Expected Results

### Before Optimization
```
$ docker images
REPOSITORY          TAG       IMAGE ID      SIZE
playwright-mcp      latest    abc123        2.5GB
```

```
$ docker stats
CONTAINER        MEM USAGE    MEM LIMIT    CPU %
playwright-mcp   512M         2GB          15-30%
```

### After Optimization (Chromium-only)
```
$ docker images
REPOSITORY          TAG       IMAGE ID      SIZE
playwright-mcp      latest    def456        1.2GB  ← 52% reduction
```

```
$ docker stats
CONTAINER        MEM USAGE    MEM LIMIT    CPU %
playwright-mcp   256M         1.5GB        5-15%   ← 50% less memory
```

### After Ultra-Slim Build
```
$ docker images
REPOSITORY          TAG            IMAGE ID      SIZE
playwright-mcp      ultra-slim     ghi789        800MB  ← 68% reduction
```

---

## 🔍 Verification Checklist

- [ ] Image size is significantly smaller (`docker images`)
- [ ] Container starts successfully (`docker-compose up -d`)
- [ ] Health check passes (`docker-compose ps`)
- [ ] MCP server responds (`curl http://localhost:40001/mcp`)
- [ ] Memory usage is lower (`docker stats`)
- [ ] Chromium browser works (`docker exec playwright-mcp ps aux | grep chromium`)

---

## 🛠️ Troubleshooting

### Issue: "Chromium not found"
```bash
# Verify Chromium is installed
docker exec playwright-mcp which chromium

# Or check Playwright config
docker exec playwright-mcp npx playwright install chromium
```

### Issue: "Out of memory" with ultra-slim
```yaml
# Increase memory
deploy:
  resources:
    limits:
      memory: "2G"  # Increase from 1.5G
shm_size: 2gb       # Increase from 1gb
```

### Issue: Build takes too long
```bash
# Enable BuildKit cache
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
docker-compose build --progress=plain
```

### Issue: Container restarts frequently
```bash
# Check logs
docker-compose logs -f

# Increase health check timeout
healthcheck:
  timeout: 15s  # Increase from 10s
  start_period: 20s  # Increase from 15s
```

---

## 📋 Configuration Files

### Files Provided:
1. **Dockerfile.optimized** - Chromium-only (1.2GB)
2. **Dockerfile.ultra-slim** - Node + minimal Chromium (800MB)
3. **docker-compose.optimized.yml** - Reduced resources
4. **.dockerignore.optimized** - Comprehensive ignore list

### Files to Use:
```bash
# Quick optimization (most recommended)
cp Dockerfile.optimized Dockerfile
cp docker-compose.optimized.yml docker-compose.yml
cp .dockerignore.optimized .dockerignore

# Then rebuild
docker-compose up -d --build --force-recreate
```

---

## 📚 References

- [Docker Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Playwright Docker Docs](https://playwright.dev/docs/docker)
- [Node.js Docker Images](https://hub.docker.com/_/node)

---

## 💡 Summary

| Action | Savings | Effort | Recommendation |
|--------|---------|--------|-----------------|
| Use chromium-only image | 1.3GB | ⭐ | **DO THIS FIRST** |
| Optimize .dockerignore | 100MB+ | ⭐ | Yes |
| Reduce shm_size | 1GB | ⭐ | Yes |
| Reduce memory limits | - | ⭐ | Yes |
| Use ultra-slim build | 1.7GB | ⭐⭐ | If first build time is acceptable |
| Multi-stage builds | 200MB+ | ⭐⭐⭐ | Advanced optimization |

**Expected final size:** 800MB-1.2GB (vs 2.5GB+ originally)
**Expected memory savings:** 50% reduction at runtime
