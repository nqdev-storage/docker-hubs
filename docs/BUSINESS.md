# Tài liệu Quy trình Nghiệp vụ — docker-hubs

## Tổng quan dự án

**docker-hubs** là repo chứa Docker image + compose setup cho **OpenCode** — self-hosted AI code tool router. Cho phép kết nối nhiều AI code tools đến 40+ AI providers và 100+ models. Repo này custom hóa base image `ghcr.io/anomalyco/opencode` với các công cụ bổ sung (Python, Node.js, Chromium, Playwright MCP) và quản lý vòng đời container qua docker-compose.

**Mục đích**: Tạo distribution-ready Docker image cho OpenCode, publish lên GHCR, tự động hóa bằng GitHub Actions.

## Actors / Vai trò

| Actor | Vai trò |
|-------|---------|
| **Developer** | Build, chạy, và debug OpenCode container local |
| **CI/CD (GitHub Actions)** | Tự động build, tag, push image lên GHCR |
| **End User** | Sử dụng OpenCode qua web UI (port 10026) |
| **Container Runtime (Docker)** | Chạy container với quyền privileged để MITM networking |

## Entities / Thực thể

### 1. Docker Image (`ghcr.io/nqdev-outsource/opencode`)

- **Base**: `ghcr.io/anomalyco/opencode:1.17.11` (Alpine-based)
- **Thêm**: python3, nodejs, git, chromium, curl, bash, util-linux, coreutils
- **Config MCP được built-in** tại `/root/.config/opencode/mcp.json`:
  - **playwright** (local): `@playwright/mcp@latest` — browser automation, headless Chromium, caps=network,storage,testing,vision,devtools
  - **slim-tools** (remote): `https://slim.tools/mcp` — 5s timeout
- **Entrypoint**: `opencode` binary
- **Image version**: Được ghi bằng LABEL qua build arg `IMAGE_VERSION`

### 2. Container (`opencode-10026`)

| Property | Value |
|----------|-------|
| Port mapping | `10026:4096` |
| Privileged | true (MITM networking) |
| Restart | unless-stopped |
| Resources | 4 CPU / 8G RAM limit, 256M reserved |
| DNS | Cloudflare (1.1.1.1, 1.0.0.1) + Google (8.8.8.8) + local (115.84.181.20) |
| Volumes | `./data/oc-local`, `./data/oc-config`, `./data/wps` |
| Auth | `OPENCODE_SERVER_USERNAME` / `OPENCODE_SERVER_PASSWORD` từ `.env` |

### 3. GitHub Workflows

#### a. Build & Push (`opencode-docker-publish.yml`)
- **Trigger**: Tag push `v*` hoặc `workflow_dispatch`
- **Output tags**:
  - Tag push: `{{VERSION}}-rc{{run_number}}` + `latest`
  - Manual: `{{VERSION}}-rc{{run_number}}-manual`
- **Registry**: GHCR (active), Docker Hub (commented out)
- **Build cache**: Registry cache mode=max

#### b. Changelog (`changelog.yml`)
- **Trigger**: Tag push `v*` hoặc `workflow_dispatch`
- **Tool**: `auto-changelog` (npm)
- **Output**: `CHANGELOG-NQDEV.md`
- **Output version file**: `.version.txt` (từ `VERSION` hoặc `v*` tag)

### 4. VERSION File

- Source of truth: `opencode/VERSION` (hiện tại `1.17.11`)
- Được dùng bởi publish workflow để tag image
- `set-version` action đọc root `VERSION` — hiện ít dùng

## Workflows / Luồng nghiệp vụ

### Flow 1: Local Development

```
Developer
  │
  ├── 1. Chạy: docker-compose -f opencode/docker-compose.yml up -d --build
  │     └── Build image từ Dockerfile (cài python, node, chromium, mcp config)
  │     └── Start container opencode-10026 (privileged, port 10026)
  │
  ├── 2. Truy cập: http://localhost:10026
  │     └── OpenCode web UI (yêu cầu username/password từ .env)
  │
  ├── 3. Debug: docker exec -it opencode-10026 script -q -c "bash"
  │
  └── 4. Dừng: docker-compose -f opencode/docker-compose.yml down -v
```

### Flow 2: Release & Publish (GitHub Actions)

```
Maintainer
  │
  ├── 1. Bump version trong opencode/VERSION
  │
  ├── 2. Git tag v* && git push --tags
  │     └── Trigger 2 workflows song song:
  │
  │     ├── [Build & Push]
  │     │   ├── Read version từ opencode/VERSION
  │     │   ├── Login GHCR
  │     │   ├── Build multi-stage với buildkit
  │     │   ├── Tag: VERSION-rcRUN và latest
  │     │   ├── Push lên ghcr.io/nqdev-outsource/opencode
  │     │   └── Cache registry mode=max
  │     │
  │     └── [Changelog]
  │         ├── Read version từ VERSION / tag
  │         ├── Viết .version.txt
  │         ├── auto-changelog → CHANGELOG-NQDEV.md
  │         └── Commit & push CHANGELOG-NQDEV.md về repo
  │
  └── 3. (Optional) workflow_dispatch để manual build
```

### Flow 3: MCP Service Discovery (Runtime)

```
Container Start
  │
  └── opencode entrypoint
      └── Đọc /root/.config/opencode/mcp.json
          │
          ├── playwright (local)
          │   └── npx @playwright/mcp@latest --browser=chromium --headless
          │       └── Cung cấp: network, storage, testing, vision, devtools caps
          │
          └── slim-tools (remote)
              └── HTTP to https://slim.tools/mcp (5s timeout)
                  └── Cung cấp: web search, fetch tools
```

## Security Notes

- Container chạy **privileged** — cần thiết cho MITM networking (host traffic interception)
- Auth dùng basic username/password từ `.env` file
- MCP playwright có `testing` cap — cho phép browser automation
- GitHub token được dùng cho GHCR login (permissions: packages.write)
- Docker Hub login bị **comment out** — không active

## Known Issues & Limitations

1. **Docker Hub publish disabled** — login step commented out trong workflow
2. **set-version action** đọc root `VERSION` nhưng source of truth là `opencode/VERSION` — inconsistency nhỏ
3. **changelog workflow** push trực tiếp lên default branch — không qua PR
4. **VERSION trong compose** (`1.17.9`) không đồng bộ với `opencode/VERSION` (`1.17.11`)
