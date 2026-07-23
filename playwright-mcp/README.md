# Playwright MCP Server

Playwright Model Context Protocol (MCP) Server chạy trong Docker với cấu hình tối ưu.

## 📋 Yêu cầu

- Docker & Docker Compose
- Port 40001 khả dụng

## 🚀 Cách sử dụng

### 1. **Khởi động**

```bash
# Build image + Start container
docker-compose up -d --build --force-recreate --remove-orphans

# Hoặc chỉ start nếu đã build
docker-compose up -d
```

### 2. **Xem logs**

```bash
# Real-time logs
docker-compose logs -f

# Logs của container cụ thể
docker-compose logs -f playwright-mcp
```

### 3. **Kiểm tra trạng thái**

```bash
# Xem container status
docker-compose ps

# Test kết nối
curl http://localhost:40001/mcp

# Health check
docker-compose exec playwright-mcp curl http://localhost:8931/
```

### 4. **Truy cập shell**

```bash
docker-compose exec playwright-mcp bash
```

### 5. **Dừng container**

```bash
# Stop
docker-compose down

# Stop + xóa volumes
docker-compose down -v

# Stop + xóa images
docker-compose down -v --rmi all
```

---

## 📡 Cấu hình Client

### Kết nối từ localhost

```json
{
  "mcpServers": {
    "playwright": {
      "url": "http://localhost:40001/mcp"
    }
  }
}
```

### Kết nối từ máy khác trong network

```json
{
  "mcpServers": {
    "playwright": {
      "url": "http://192.168.1.200:40001/mcp"
    }
  }
}
```

### SSE Transport (legacy)

```json
{
  "mcpServers": {
    "playwright": {
      "url": "http://localhost:40001/sse"
    }
  }
}
```

---

## 🔧 Cấu hình

### Environment Variables

Sửa `docker-compose.yml`:

```yaml
environment:
  - TZ=Asia/Ho_Chi_Minh        # Timezone
  - NODE_ENV=production         # Node environment
  - NPM_CONFIG_LOGLEVEL=warn   # NPM log level
```

### Resource Limits

Sửa `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: "0.50"      # CPU limit
      memory: "2G"      # Memory limit
    reservations:
      memory: "256M"    # Guaranteed memory
```

### Shared Memory

Cho browser instances:

```yaml
shm_size: 2gb  # Tăng nếu cần
```

---

## 📊 Dockerfile Details

- **Base Image**: `mcr.microsoft.com/playwright:v1.54.2-noble`
- **Browser**: Chrome (đã cài đặt)
- **Port**: 8931
- **Health Check**: Enabled

---

## 🐛 Troubleshooting

### Container không start

```bash
# Xem chi tiết error
docker-compose logs playwright-mcp

# Rebuild
docker-compose down -v --rmi all
docker-compose up -d --build
```

### Port 40001 đã bị chiếm

```bash
# Tìm process chiếm port
lsof -i :40001

# Hoặc đổi port trong docker-compose.yml
ports:
  - "40002:8931"  # Thay 40002 thay cho 40001
```

### Out of memory

Tăng `shm_size` hoặc `memory` limit:

```yaml
shm_size: 4gb  # Tăng từ 2gb
deploy:
  resources:
    limits:
      memory: "4G"  # Tăng từ 2G
```

### CPU usage cao

```bash
# Giảm CPU limit nếu không cần
cpus: "0.25"  # Giảm từ 0.50
```

---

## 📝 Cheat Sheet

| Command | Purpose |
|---------|---------|
| `docker-compose up -d` | Start |
| `docker-compose down` | Stop |
| `docker-compose logs -f` | View logs |
| `docker-compose ps` | Status |
| `docker-compose exec playwright-mcp bash` | Shell |
| `docker-compose restart` | Restart |
| `docker-compose rebuild` | Rebuild image |

---

## 🔗 Resources

- [Playwright MCP Docs](https://playwright.dev/docs/getting-started-mcp)
- [Playwright Docker](https://playwright.dev/docs/docker)
- [Docker Compose Docs](https://docs.docker.com/compose/)

---

**Version**: v1.54.2  
**Last Updated**: 2024
