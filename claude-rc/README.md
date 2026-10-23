# Claude Code Remote Control trong Docker

Image chạy `claude remote-control` (server mode) trong container, điều khiển từ claude.ai/code hoặc app Claude trên điện thoại.

- Image: `ghcr.io/nqdev-storage/claude-rc:<tag>` (tag theo phiên bản Claude Code, xem file `VERSION`)
- Base: `node:22-bookworm-slim` (Debian 12)
- User chạy: `node` (UID 1000), thư mục làm việc `/workspace`

## 1. Trong image có sẵn những gì

### Runtime & công cụ hệ thống (apt)

| Nhóm | Gói / công cụ | Ghi chú |
|---|---|---|
| Node.js | Node 22 + npm | Từ base image |
| Git & mạng | `git`, `curl`, `ca-certificates`, `openssh-client` | Dùng clone/push, tải file, SSH |
| Tìm kiếm / tiện ích | `ripgrep` (`rg`), `jq`, `less`, `procps`, `unzip` | `rg` là công cụ search mà Claude Code ưu tiên dùng |
| Init process | `tini` | PID 1 – dọn zombie process, chuyển tiếp signal |
| Python | `python3`, `python3-dev`, `python3-pip`, `python3-venv` | Kèm `build-essential` để build package native |
| Trình duyệt | `chromium` | Headless browser cho scraping/test/screenshot |
| Font | `fonts-liberation`, `fonts-noto-color-emoji`, `fonts-noto-cjk` | Render đúng chữ Latin, emoji, tiếng Trung/Nhật/Hàn |

### Công cụ cài qua npm (global)

| Package | Mục đích |
|---|---|
| `@anthropic-ai/claude-code` | Claude Code CLI (`claude`). Phiên bản lấy theo build arg `CLAUDE_CODE_VERSION` |
| `localtunnel` | Mở tunnel public (`lt --port ...`) để expose service trong container |

### Python

- Venv dùng chung tại `/opt/venv`, đã nằm sẵn trong `PATH` → `pip install ...` chạy thẳng, **không bị lỗi PEP 668** của Debian 12.
- Owner của venv là user `node` nên không cần `sudo`.

### Khác

- `/bin/sh` được trỏ sang `bash`.
- Git đã cấu hình sẵn `user.name`, `user.email` (từ build arg) và `safe.directory /workspace`.
- Múi giờ mặc định `Asia/Ho_Chi_Minh`.

> Image **không** có: Docker CLI, `gh` (GitHub CLI), Playwright browser (đã tắt tải về, dùng Chromium của hệ thống), `sudo`. Cần thêm thì sửa `Dockerfile`.

## 2. Cấu hình khi chạy image

### 2.1 Biến môi trường dựng sẵn trong image

| Biến | Giá trị mặc định | Ý nghĩa |
|---|---|---|
| `TZ` | `Asia/Ho_Chi_Minh` | Múi giờ container |
| `NODE_ENV` | `production` | |
| `NPM_CONFIG_LOGLEVEL` | `error` | Giảm log npm |
| `CLAUDE_CONFIG_DIR` | `/home/node/.claude` | Nơi lưu login, trust, settings, lịch sử session |
| `VIRTUAL_ENV` | `/opt/venv` | Python venv (đã thêm vào `PATH`) |
| `CHROME_BIN` | `/usr/bin/chromium` | Đường dẫn Chromium |
| `PUPPETEER_EXECUTABLE_PATH` | `/usr/bin/chromium` | Puppeteer dùng Chromium hệ thống |
| `PUPPETEER_SKIP_DOWNLOAD` | `true` | Không tải Chromium riêng |
| `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD` | `1` | Không tải browser của Playwright |

### 2.2 Biến môi trường nên truyền khi `docker run` / compose

Copy `.env.example` → `.env` rồi điền giá trị thật (không commit `.env`).

| Biến | Bắt buộc | Ý nghĩa |
|---|---|---|
| `TZ` | Không | Ghi đè múi giờ |
| `GITHUB_USERNAME`, `GITHUB_TOKEN` | Không | Thông tin GitHub (PAT) để dùng trong container |
| `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME`, `GIT_COMMITTER_EMAIL` | Không | Danh tính commit (ghi đè git config mặc định của image) |
| `GIT_TERMINAL_PROMPT=0` | Khuyến nghị | Git không hỏi mật khẩu tương tác |
| `GITHUB_API_URL` | Không | Dùng khi gọi GitHub API / GitHub Enterprise |
| `CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX` | Không | Prefix tên session tự sinh |

> Lưu ý: image chỉ nhận các biến này, **không tự cấu hình credential helper** cho `GITHUB_TOKEN`. Nếu muốn `git push` qua HTTPS bằng token, cần tự cấu hình (credential helper / URL có token) hoặc mount `~/.ssh`.

### 2.3 Volume cần mount

| Đường dẫn trong container | Bắt buộc | Mục đích |
|---|---|---|
| `/home/node/.claude` | **Có** | Lưu login, trust, settings, lịch sử session. Mất volume = phải login lại |
| `/workspace` | **Có** | Thư mục project Claude làm việc |
| `/home/node/.gitconfig` (ro) | Không | Dùng git config của host |
| `/home/node/.ssh` (ro) | Không | Dùng SSH key của host để push/pull |

### 2.4 Lệnh khởi động (`ENTRYPOINT` / `CMD`)

```text
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["claude", "remote-control", "--name", "Docker RC"]
```

Có thể ghi đè `CMD` (trong compose là `command:`) với các tham số của `claude remote-control`:

| Tham số | Ý nghĩa |
|---|---|
| `--name <tên>` | Tên session hiển thị trên claude.ai/code |
| `--spawn same-dir` \| `worktree` | `worktree`: mỗi session có git worktree riêng (cần `/workspace` là git repo) |
| `--capacity N` | Số session đồng thời tối đa (mặc định 32) |
| `--permission-mode acceptEdits` | Chế độ quyền (tránh `bypassPermissions` trừ khi container thật sự cô lập) |
| `--verbose` | Bật log chi tiết để debug kết nối |

### 2.5 Container flags khuyến nghị

- `stdin_open: true` + `tty: true` (`-it`): **bắt buộc** để trả lời prompt Trust / Enable Remote Control và dùng phím tắt (Space = QR).
- `restart: unless-stopped`: server mode tự thoát sau ~10 phút mất mạng, cần tự khởi động lại.
- Mạng: chỉ cần **outbound HTTPS 443**, không cần publish port.
- Giới hạn tài nguyên (ví dụ trong compose): CPU 0.5, RAM 2G.

### 2.6 Build args (khi tự build image)

| Arg | Mặc định | Ý nghĩa |
|---|---|---|
| `IMAGE_VERSION` | `dev` | Gắn vào label `version` |
| `CLAUDE_CODE_VERSION` | `latest` | Khai báo phiên bản Claude Code |
| `GIT_USER_NAME` | `OpenCode v2` | `git config user.name` mặc định |
| `GIT_USER_EMAIL` | `opencode@quyit.id.vn` | `git config user.email` mặc định |

```bash
docker build -t claude-rc:latest --build-arg IMAGE_VERSION=2.1.306 .
```

## 3. Yêu cầu tài khoản (theo docs)

- Tài khoản **Pro / Max / Team / Enterprise**. Team/Enterprise: Owner phải bật toggle Remote Control trong admin settings.
- Đăng nhập bằng **claude.ai qua `claude auth login`**. Không dùng được:
  - `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `apiKeyHelper`
  - token từ `claude setup-token` / `CLAUDE_CODE_OAUTH_TOKEN` (thiếu scope cho Remote Control)
- Không đặt `ANTHROPIC_BASE_URL` khác `api.anthropic.com`, không dùng Bedrock/Vertex/Foundry.
- Không đặt `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` hoặc `DISABLE_GROWTHBOOK`.

## 4. Hướng dẫn sử dụng nhanh

```bash
cp .env.example .env          # điền giá trị thật
mkdir -p data/workspace data/claude-config
```

### Bước 1. Đăng nhập (một lần)

Mở shell bash trong container trước, rồi mới login bên trong (chạy thẳng `claude auth login` qua `docker compose run` dễ lỗi `Login failed: Request failed with status code 400` khi dán code):

```bash
docker compose run --rm --entrypoint bash claude-rc
claude auth login
```

Chọn đăng nhập claude.ai → mở URL trên trình duyệt máy bạn → dán code vào terminal → `exit`.
Login được lưu ở `/home/node/.claude` nên không cần login lại khi rebuild/restart.

### Bước 2. Chạy lần đầu tương tác (trả lời 2 prompt)

```bash
docker compose run --rm claude-rc
```

- `Trust /workspace? [y/N]` → `y`
- `Enable Remote Control? (y/n)` → `y`

Thấy URL session là OK → `Ctrl+C`. Lựa chọn đã được lưu.

### Bước 3. Chạy nền

```bash
docker compose up -d
docker attach claude-rc       # xem URL, Space = QR; thoát không tắt container: Ctrl+P rồi Ctrl+Q
```

Mở **claude.ai/code** hoặc app Claude → tab **Code** → chọn session `Docker RC` (icon máy tính, chấm xanh).

## 5. Vận hành

| Việc | Lệnh |
|---|---|
| Xem log | `docker compose logs -f` |
| Kiểm tra lỗi eligibility | `docker compose exec claude-rc claude doctor` |
| Cập nhật Claude Code | `docker compose build --no-cache && docker compose up -d` (hoặc đổi tag image) |
| Login lại (đổi plan / lỗi entitlement) | `docker compose exec claude-rc bash` → `claude auth logout` → `claude auth login` |
| Debug kết nối | thêm `--verbose` vào `command` |

- Khi container restart, `claude remote-control` **mang lại các session cũ** nếu trong ~4 giờ (cùng thư mục, volume config còn nguyên).
- Server mode tự thoát sau ~10 phút mất mạng; `restart: unless-stopped` sẽ dựng lại.

## 6. Lưu ý

- **Quyền file**: container chạy user `node` (UID 1000). Nếu thư mục host thuộc UID khác, `chown 1000:1000` hoặc build lại với user phù hợp.
- **Git trong container**: mount `~/.gitconfig` và `~/.ssh` (read-only) nếu muốn Claude commit/push.
- **MCP server cục bộ**: phải chạy được *bên trong* container (cài thêm runtime vào Dockerfile nếu cần).
- **Bảo mật**: ai đăng nhập được tài khoản claude.ai của bạn là điều khiển được container này. Cân nhắc bật *Require trusted devices* trong Account settings. Hạn chế volume mount ở mức cần thiết; tránh `bypassPermissions` trừ khi container thật sự cô lập.
