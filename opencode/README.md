# OpenCode (Docker)

Image Docker tuỳ chỉnh cho [OpenCode](https://opencode.ai/v2/docs) (AI coding agent chạy dạng server/web UI). Image mở rộng từ `ghcr.io/anomalyco/opencode` và cài sẵn Python, Node.js, Chromium, Git cùng một MCP server Playwright.

README này trả lời 2 câu hỏi: **trong image có sẵn gì** và **khi chạy image cần cấu hình gì**. Kiến trúc chung, CI/CD của repo xem [`../AGENTS.md`](../AGENTS.md).

## Chạy nhanh

```bash
# 1. Tạo .env từ mẫu rồi đổi password
cp .env.example .env

# 2. Khởi động (docker-compose.yml dùng image dựng sẵn trên GHCR, không build local)
docker-compose up -d --force-recreate --remove-orphans

# 3. Mở web UI: http://localhost:10029  (đăng nhập bằng OPENCODE_SERVER_USERNAME / PASSWORD)

# Vào shell trong container
docker exec -it opencode-10029 script -q -c "bash"

# Dừng và dọn dẹp
docker-compose down -v --remove-orphans
```

Chạy trực tiếp không qua compose:

```bash
docker run -d --name opencode -p 10029:4096 \
  -e OPENCODE_SERVER_PASSWORD=change-me \
  -v ./data/oc-local:/root/.local/share/opencode \
  -v ./data/oc-config:/root/.config/opencode \
  ghcr.io/nqdev-storage/opencode:<tag> \
  serve --hostname 0.0.0.0 --port 4096
```

> `ENTRYPOINT` của image là `opencode`, nên phần sau tên image là **tham số của opencode** (không phải lệnh shell). Image không có `CMD` mặc định, bắt buộc truyền lệnh như `serve ...`.

## Trong image có sẵn gì

### Base image

| Mục | Giá trị |
|-----|---------|
| Base | `ghcr.io/anomalyco/opencode:2.1.4` (Alpine Linux) |
| Build arg | `IMAGE_VERSION` → gắn vào label `version` |
| Label | `title="OpenCode v2"`, `description=...` |

### Công cụ cài thêm (qua `apk`)

| Gói | Dùng để |
|-----|---------|
| `python3`, `python3-dev`, `py3-pip` | Chạy script Python, cài package pip có phần biên dịch native |
| `nodejs`, `npm` | Chạy `npx`, các MCP server/LSP viết bằng Node |
| `git` | Thao tác repo |
| `bash` | Shell chính (`/bin/sh` được symlink sang `/bin/bash`) |
| `util-linux`, `coreutils` | Bản GNU của các lệnh cơ bản (kể cả `script`, dùng cho `docker exec ... script -q -c bash`) |
| `curl` | Gọi HTTP, tải file |
| `chromium` | Trình duyệt headless cho Playwright MCP |

Lúc build có bước kiểm tra `node`, `npm`, `python3`, `git --version`, nên build lỗi nếu thiếu công cụ nào.

### MCP server cấu hình sẵn

File `/root/.config/opencode/mcp.json` được ghi lúc build:

| MCP | Loại | Lệnh | Ghi chú |
|-----|------|------|---------|
| `playwright` | local, `enabled: true` | `npx -y @playwright/mcp@latest --browser=chromium --headless --caps=network,storage,testing,vision,devtools` | Điều khiển Chromium trong container. Package được `npx` tải **khi chạy lần đầu** (cần internet) |

### Biến môi trường được set sẵn trong image

| Biến | Giá trị | Ý nghĩa |
|------|---------|---------|
| `TZ` | `Asia/Ho_Chi_Minh` | Múi giờ |
| `NODE_ENV` | `production` | |
| `NPM_CONFIG_LOGLEVEL` | `error` | npm chỉ in lỗi |
| `NODE_OPTIONS` | `--require /opt/opencode-preload/index.js` | Nạp file preload cho mọi tiến trình Node |

### Preload polyfill

`/opt/opencode-preload/` (nguồn: [`preload/`](preload/)) polyfill `crypto.randomUUID` để tương thích với các JS context bị cô lập (tính năng upload/context). Không cần cấu hình gì; chỉ cần biết nó chạy trước mọi tiến trình Node, kể cả `npx`.

## Cấu hình khi chạy image

### Biến môi trường

Compose đọc từ `.env` (mẫu: [`.env.example`](.env.example), có kèm danh sách đầy đủ các biến `OPENCODE_*` ở dạng comment).

| Biến | Mặc định (compose) | Mô tả |
|------|--------------------|-------|
| `OPENCODE_SERVER_USERNAME` | `opencode` | User basic-auth cho web UI / `opencode serve` |
| `OPENCODE_SERVER_PASSWORD` | `password` | Password. **Phải đổi** khi mở ra ngoài |
| `WAKATIME_API_KEY` | `ak-api-key` | Tuỳ chọn, plugin/CLI WakaTime đọc trực tiếp |
| `TZ` | `Asia/Ho_Chi_Minh` | Múi giờ container |

Một số biến `OPENCODE_*` hay dùng (đặt trong `.env`, mặc định tắt):

| Biến | Tác dụng |
|------|----------|
| `OPENCODE_CONFIG` / `OPENCODE_CONFIG_DIR` / `OPENCODE_CONFIG_CONTENT` | Chỉ định file, thư mục hoặc nội dung JSON inline của config |
| `OPENCODE_PERMISSION` | Permission dạng JSON inline |
| `OPENCODE_DISABLE_AUTOUPDATE` | Tắt tự cập nhật |
| `OPENCODE_DISABLE_LSP_DOWNLOAD` | Không tự tải LSP server |
| `OPENCODE_DISABLE_CLAUDE_CODE` | Không đọc `.claude` (prompt + skills) |
| `OPENCODE_DB` | (v2) Đường dẫn database |

> Các biến lấy từ docs v1, một số có thể không còn áp dụng ở v2. Kiểm tra bằng `opencode --help`.

### Lệnh khởi chạy

| Phiên bản | `command` |
|-----------|-----------|
| v2 (đang dùng) | `serve --hostname 0.0.0.0 --port 4096` |
| v1 | `web --hostname 0.0.0.0 --port 4096` |

`--hostname 0.0.0.0` là bắt buộc để truy cập được từ ngoài container. Port nội bộ là `4096`.

### Volume (dữ liệu cần giữ lại)

| Host | Container | Nội dung |
|------|-----------|----------|
| `./data/oc-local` | `/root/.local/share/opencode/` | Database, session, log, auth |
| `./data/oc-config` | `/root/.config/opencode/` | Config người dùng (provider, model, MCP...) |
| `./data/oc-cache` | `/root/.cache/opencode` | Cache (LSP server đã tải...). Mất thì lần sau tải lại |
| `./data/oc-state` | `/root/.local/state/opencode` | State |
| `./data/wps` | `/app/data` | Dữ liệu làm việc/persistent |

> **Lưu ý:** mount `./data/oc-config` lên `/root/.config/opencode/` sẽ **che** file `mcp.json` đã ghi sẵn trong image. Nếu muốn dùng MCP Playwright mặc định, hãy tự đặt cấu hình MCP vào thư mục `data/oc-config` trên host.

### Container, mạng và tài nguyên (theo `docker-compose.yml`)

| Mục | Giá trị |
|-----|---------|
| Tên container | `opencode-10029` |
| Port | `10029:4096` |
| User / quyền | `root`, `privileged: true` (cần cho can thiệp mạng kiểu MITM) |
| DNS | `1.1.1.1`, `1.0.0.1`, `8.8.8.8`, `8.8.4.4` |
| `extra_hosts` | `host.docker.internal` → host gateway; `minipc-quyit` → `192.168.1.200` |
| ulimits | `nproc` 65536; `nofile` 102400 (soft/hard) |
| Giới hạn | 1 CPU / 4G RAM, đảm bảo tối thiểu 256M RAM |
| Restart | `unless-stopped` |

`privileged: true` và chạy root cấp quyền rất rộng. Chỉ dùng trên máy tin cậy và đừng expose port ra Internet mà không có password mạnh.

## Build local

`docker-compose.yml` mặc định kéo image từ GHCR (khối `build:` đang comment). Build từ `Dockerfile` ở thư mục này (build context phải là thư mục cha vì `Dockerfile` copy `./opencode/preload/`):

```bash
# chạy tại thư mục gốc repo
docker build -f opencode/Dockerfile --build-arg IMAGE_VERSION=$(cat opencode/VERSION) -t opencode:local .
```

Nếu bật `build:` trong compose, đặt `context: ..` và `dockerfile: opencode/Dockerfile`.

## Các file trong thư mục

| File | Mục đích |
|------|----------|
| `Dockerfile` | Định nghĩa image |
| `docker-compose.yml` | Chạy container (port, volume, giới hạn tài nguyên) |
| `docker-compose.v1.yml` | Compose cho OpenCode v1 (cũ) |
| `.env.example` | Mẫu biến môi trường |
| `preload/` | Polyfill `crypto.randomUUID` nạp qua `NODE_OPTIONS` |
| `VERSION` | Số version của image |
| `data/` | Dữ liệu persistent (không commit) |

## Lưu ý

- Tag image trong `docker-compose.yml` là bản đã publish, có thể **khác** base image trong `Dockerfile`. Sửa `Dockerfile` mà chưa publish và đổi tag thì hai bên sẽ lệch nhau.
- Header comment của `docker-compose.yml` còn ghi tên container cũ (`opencode-10026`); container thật là `opencode-10029`.
