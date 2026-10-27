# Claude Code Remote Control trong Docker

Image chạy `claude remote-control` (server mode) trong container, điều khiển từ claude.ai/code hoặc app Claude trên điện thoại.

- Image: `ghcr.io/nqdev-storage/claude-rc:<tag>` (build bằng GitHub Actions, xem [mục 2.6](#26-build))
- Base: `node:22-bookworm-slim` (Debian 12)
- User chạy: `node` (UID 1000), thư mục làm việc `/workspace`
- Mạng: chỉ cần **outbound HTTPS 443**, không publish port

Mục lục: [1. Trong image có gì](#1-trong-image-có-gì) · [2. Cấu hình khi chạy](#2-cấu-hình-khi-chạy) · [3. Thư mục include và scripts](#3-thư-mục-include-và-scripts) · [4. Yêu cầu tài khoản](#4-yêu-cầu-tài-khoản) · [5. Chạy nhanh](#5-chạy-nhanh) · [6. Public review](#6-public-review-qua-localtunnel) · [7. Vận hành](#7-vận-hành) · [8. Lưu ý](#8-lưu-ý)

## 1. Trong image có gì

### Công cụ hệ thống (apt)

| Nhóm | Công cụ | Ghi chú |
|---|---|---|
| Node.js | Node 22 + npm | Từ base image |
| Git & mạng | `git`, `curl`, `ca-certificates`, `openssh-client` | Clone/push, tải file, SSH |
| Tiện ích | `ripgrep` (`rg`), `jq`, `less`, `procps`, `unzip` | `rg` là công cụ search Claude Code ưu tiên dùng |
| Init | `tini` | PID 1: dọn zombie process, chuyển tiếp signal |
| Python | `python3`, `python3-pip`, `python3-venv` | Không có `build-essential`/`python3-dev` (giảm size): package Python phải build từ source sẽ lỗi. Cần thì thêm hai gói đó vào dòng `apt-get install` trong Dockerfile rồi build lại |
| Trình duyệt | `chromium` | Headless browser (scraping, test, screenshot) |
| Font | `fonts-liberation`, `fonts-noto-color-emoji` | Chữ Latin và emoji. Không có `fonts-noto-cjk` (giảm size) nên Chromium không hiển thị chữ Trung/Nhật/Hàn |

### Công cụ npm (global)

| Package | Mục đích |
|---|---|
| `@anthropic-ai/claude-code` | Claude Code CLI (`claude`). Lấy bản mới nhất tại thời điểm build (không ghim phiên bản) |
| `localtunnel` | Tunnel public (`lt --port ...`) để người khác review app trong container |
| `bun` | Bun runtime, cung cấp `bun` và `bunx` |

### Python

Venv dùng chung ở `/opt/venv`, đã nằm trong `PATH`, owner là `node` → `pip install ...` chạy thẳng, không dính lỗi PEP 668 của Debian 12, không cần `sudo`.

### Java & Maven (không cài sẵn, cài khi cần)

Để giảm kích thước image, Java và Maven **không** có sẵn. Khi cần, chạy script (trong container, không cần root):

```bash
10-install-java-maven.sh              # JDK 17 (Temurin) + Maven 3.9.6
10-install-java-maven.sh java         # chỉ Java
10-install-java-maven.sh maven        # chỉ Maven
JAVA_VERSION=21 MAVEN_VERSION=3.9.9 10-install-java-maven.sh   # phiên bản khác
```

- Script tải Temurin từ Adoptium và Maven từ Apache (có kiểm tra SHA-512), cài vào `/home/node/.local/opt/java` và `/home/node/.local/opt/maven`, chạy lại thì bỏ qua nếu đã đủ phiên bản. Đã thử: cài Temurin 17.0.21 + Maven 3.9.6 chạy đúng (Java ~320MB, Maven ~11MB, lần đầu tải mất vài phút).
- **Tự cài khi khởi động:** đặt `INSTALL_JAVA_MAVEN=true` trong `.env` (mặc định `false`); `00-entrypoint.sh` gọi script trước khi chạy lệnh chính. Khởi động chậm hơn ở lần đầu; nếu cài lỗi (vd mất mạng) chỉ cảnh báo, không chặn khởi động.
- Image đã đặt sẵn `JAVA_HOME`, `MAVEN_HOME` và `PATH` trỏ tới hai thư mục trên, nên cài xong dùng `java`, `mvn` ngay. Khi chưa cài, `JAVA_HOME` trỏ vào thư mục chưa tồn tại (vô hại nếu bạn không dùng Java).
- Cài vào lớp ghi của container nên **mất khi recreate container**. Muốn giữ: mount `./data/opt:/home/node/.local/opt` (cache Maven ở `~/.m2`, mount thêm `./data/m2:/home/node/.m2` nếu cần).

### Plugin cài sẵn: claude-memory-hub

[`claude-memory-hub`](https://github.com/TranHoaiHung/claude-memory-hub) (bộ nhớ dài hạn cho Claude Code) được cài lúc build bằng `bunx claude-memory-hub@latest install`:

- MCP server + 7 hook (SessionStart, UserPromptSubmit, PostToolUse, PreCompact, PostCompact, Stop, SessionEnd) trong `~/.claude/settings.json`
- Slash command `/mem-search`, `/mem-status`, `/mem-save`
- Runtime và DB SQLite ở `~/.claude-memory-hub/`
- Rule che secret: [include/claude-memory-hub/privacy.json](include/claude-memory-hub/privacy.json)
- Cache của `bunx` (~410MB, gồm onnxruntime/huggingface cho tìm kiếm ngữ nghĩa) được xóa ngay trong layer build để giảm size. Tìm kiếm ngữ nghĩa mặc định không bật; bật bằng `bunx claude-memory-hub doctor --fix` (sẽ tải lại các gói này).

Kiểm tra trong container: `bunx claude-memory-hub doctor` (lần đầu `bunx` phải tải lại gói vì cache đã xóa).

### MCP server cài sẵn: Context7

[Context7](https://context7.com) cung cấp tài liệu API mới nhất của framework/thư viện (Next.js, Tailwind, React, ...) để Claude không sinh code theo API cũ. Cài lúc build bằng:

```bash
claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp
```

- Là MCP **remote qua HTTP**: không chạy process nào trong container, chỉ cần outbound HTTPS.
- Cấu hình MCP user nằm trong `~/.claude/.claude.json` (do `CLAUDE_CONFIG_DIR`), nên được `00-entrypoint.sh` chép sang thư mục bind mount như các file khác.
- Dùng không cần API key (có giới hạn tốc độ). Muốn nâng giới hạn: lấy key ở context7.com rồi chạy lại lệnh trên trong container với `--header "CONTEXT7_API_KEY: <key>"` (đừng ghi key vào Dockerfile/repo).
- Kiểm tra: `claude mcp list` → `context7 ... Connected`.

### Slash command riêng của image

| Lệnh | Mục đích |
|---|---|
| `/rc-localtunnel [port \| lệnh chạy app]` | Chạy app nền, mở localtunnel để review từ xa, **review xong thì tắt cả app lẫn tunnel** (xem [mục 6](#6-public-review-qua-localtunnel)) |

### Cấu hình Claude Code dựng sẵn ([include/.claude/settings.json](include/.claude/settings.json))

| Cấu hình | Giá trị | Ghi chú |
|---|---|---|
| `tui` | `fullscreen` | |
| `theme` | `dark` | |
| `enableArtifact` | `true` | Cần Claude Code ≥ 2.1.242 |
| `enableWorkflows` | `true` | |
| `autoUpdatesChannel` | `latest` | Không có key bật/tắt auto-update; mặc định là bật |
| `env.ENABLE_TOOL_SEARCH` | `true` | Bật tool search cho MCP |
| `env.DISABLE_TELEMETRY` | `1` | Tắt telemetry. ⚠️ Xem [mục 4](#4-yêu-cầu-tài-khoản) |
| `hooks` | 7 hook của claude-memory-hub | `install` sẽ thay bằng bản của nó, không bị trùng |

### Khác

- `/bin/sh` trỏ sang `bash`; múi giờ mặc định `Asia/Ho_Chi_Minh`.
- Git đã có sẵn `user.name`, `user.email` (build arg) và `safe.directory /workspace`.
- Image **không** có: Docker CLI, `gh`, `sudo`, browser của Playwright (đã tắt tải về, dùng Chromium hệ thống).

## 2. Cấu hình khi chạy

### 2.1 Biến môi trường dựng sẵn

| Biến | Giá trị | Ý nghĩa |
|---|---|---|
| `TZ` | `Asia/Ho_Chi_Minh` | Múi giờ |
| `NODE_ENV` | `production` | |
| `NPM_CONFIG_LOGLEVEL` | `error` | Giảm log npm |
| `CLAUDE_CONFIG_DIR` | `/home/node/.claude` | Login, trust, settings, MCP user, lịch sử session |
| `VIRTUAL_ENV` | `/opt/venv` | Python venv (đã vào `PATH`) |
| `INSTALL_JAVA_MAVEN` | `false` | `true` thì entrypoint tự chạy `10-install-java-maven.sh` lúc khởi động |
| `JAVA_HOME`, `MAVEN_HOME` | `/home/node/.local/opt/java`, `/home/node/.local/opt/maven` | Nơi `10-install-java-maven.sh` cài vào (đã vào `PATH`, chỉ có hiệu lực sau khi cài) |
| `CHROME_BIN`, `PUPPETEER_EXECUTABLE_PATH` | `/usr/bin/chromium` | Dùng Chromium hệ thống |
| `PUPPETEER_SKIP_DOWNLOAD` / `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD` | `true` / `1` | Không tải browser riêng |

### 2.2 Biến môi trường nên truyền

Copy `.env.example` → `.env`, điền giá trị thật (không commit `.env`).

| Biến | Ý nghĩa |
|---|---|
| `GITHUB_USERNAME`, `GITHUB_TOKEN` | Thông tin GitHub (PAT) dùng trong container |
| `GIT_AUTHOR_NAME/EMAIL`, `GIT_COMMITTER_NAME/EMAIL` | Danh tính commit (ghi đè git config của image) |
| `GIT_TERMINAL_PROMPT=0` | Git không hỏi mật khẩu tương tác (khuyến nghị) |
| `GITHUB_API_URL` | Khi gọi GitHub API / Enterprise |
| `INSTALL_JAVA_MAVEN` | `true` để tự cài Java + Maven lúc khởi động |
| `CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX` | Prefix tên session tự sinh |

> Image **không tự cấu hình credential helper** cho `GITHUB_TOKEN`. Muốn `git push` qua HTTPS bằng token thì tự cấu hình, hoặc mount `~/.ssh`.

### 2.3 Volume

| Trong container | Bắt buộc | Mục đích |
|---|---|---|
| `/home/node/.claude` | **Có** | Login, trust, settings, MCP user, lịch sử. Mất = phải login lại |
| `/workspace` | **Có** | Project Claude làm việc |
| `/home/node/.claude-memory-hub` | Khuyến nghị | Runtime + DB của claude-memory-hub (giữ bộ nhớ qua các lần recreate) |
| `/home/node/.local/opt` | Không | Giữ Java/Maven đã cài (`./data/opt`) |
| `/home/node/.gitconfig` (ro), `/home/node/.ssh` (ro) | Không | Dùng git config / SSH key của host |

> **Bind mount che nội dung trong image.** `docker-compose.yml` bind-mount `./data/claude-config` → `/home/node/.claude` và `./data/claude-memory-hub` → `/home/node/.claude-memory-hub`, nên hai thư mục host trống sẽ che mất `settings.json`, `commands/`, cấu hình MCP, hook, runtime và `privacy.json` trong image. Bản gốc được lưu ở `/home/node/.image-defaults/` và [scripts/00-entrypoint.sh](scripts/00-entrypoint.sh) **tự chép phần còn thiếu** vào thư mục đã mount mỗi lần container khởi động (không ghi đè file đã có, nên login, settings bạn sửa và DB được giữ nguyên). Muốn lấy lại bản mặc định của một file thì xóa file đó trong `data/` rồi restart.

### 2.4 Lệnh khởi động

```text
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/scripts/00-entrypoint.sh"]
CMD ["claude", "remote-control", "--name", "Docker RC"]
```

`00-entrypoint.sh` chạy dưới `tini` (vẫn là PID 1):

1. Chép bổ sung file mặc định vào thư mục bind mount (không ghi đè).
2. Nếu thiếu runtime claude-memory-hub thì chạy `bunx claude-memory-hub@latest install` (lỗi, ví dụ mất mạng, chỉ cảnh báo).
3. Nếu `INSTALL_JAVA_MAVEN=true` thì chạy `10-install-java-maven.sh` (lỗi chỉ cảnh báo).
4. `exec` lệnh CMD.

Chạy shell nhưng vẫn qua entrypoint: `docker compose run --rm claude-rc bash` (không dùng `--entrypoint bash` vì sẽ bỏ qua bước khởi tạo).

Ghi đè `CMD` (compose: `command:`) với các tham số của `claude remote-control`:

| Tham số | Ý nghĩa |
|---|---|
| `--name <tên>` | Tên session trên claude.ai/code |
| `--spawn same-dir` \| `worktree` | `worktree`: mỗi session một git worktree (cần `/workspace` là git repo) |
| `--capacity N` | Số session đồng thời tối đa (mặc định 32) |
| `--permission-mode acceptEdits` | Chế độ quyền (tránh `bypassPermissions` trừ khi container cô lập) |
| `--verbose` | Log chi tiết để debug kết nối |

### 2.5 Container flags khuyến nghị

- `stdin_open: true` + `tty: true`: **bắt buộc** để trả lời prompt Trust / Enable Remote Control và dùng phím tắt (Space = QR).
- `restart: unless-stopped`: server mode tự thoát sau ~10 phút mất mạng.
- Giới hạn tài nguyên trong compose: CPU 0.5, RAM 2G.

### 2.6 Build

**GitHub Actions** ([.github/workflows/claude-rc-docker-publish.yml](../.github/workflows/claude-rc-docker-publish.yml)): build với `context: claude-rc`, `file: claude-rc/Dockerfile`, đẩy lên GHCR (và Docker Hub nếu có secret). Tag lấy từ file `VERSION` kèm `-rc<số lần chạy>`; `latest` khi push; thêm hậu tố `-manual` khi chạy bằng workflow_dispatch.

**Build tay** (chạy trong thư mục `claude-rc/`, vì build context phải là thư mục này do Dockerfile `COPY include/...` và `COPY scripts/...`):

```bash
docker build -t claude-rc:latest --build-arg IMAGE_VERSION=$(cat VERSION) .
```

| Build arg | Mặc định | Ý nghĩa |
|---|---|---|
| `IMAGE_VERSION` | `dev` | Label `version` |
| `GIT_USER_NAME` | `OpenCode v2` | `git config user.name` mặc định |
| `GIT_USER_EMAIL` | `opencode@quyit.id.vn` | `git config user.email` mặc định |

(`CLAUDE_CODE_VERSION` có trong Dockerfile nhưng chưa được dùng; Claude Code luôn lấy `latest`.) Nếu dùng `build:` trong compose: `context: .` khi đặt compose trong `claude-rc/`.

Build cần `COPY --chmod` (BuildKit), mặc định có trong Docker hiện nay.

## 3. Thư mục include và scripts

### include/

[include/](include/) chứa cấu hình copy vào image, mỗi thư mục con ứng với một đích:

| Thư mục | Copy vào | Nội dung |
|---|---|---|
| `include/.claude/` | `/home/node/.claude/` | `commands/rc-localtunnel.md`, `settings.json` |
| `include/claude-memory-hub/` | `/home/node/.claude-memory-hub/` | `privacy.json` |

Thứ tự trong Dockerfile: `include/.claude/` copy **trước** `install` của claude-memory-hub (để `install` gộp hook/MCP vào `settings.json` có sẵn); `include/claude-memory-hub/` copy **sau** `install`. Thêm thư mục mới: tạo `include/<tên>/` rồi thêm một dòng `COPY --chown=node:node include/<tên>/ <đích>` vào Dockerfile (Docker không tự map theo tên thư mục).

### scripts/

[scripts/](scripts/) chứa script chạy hoặc cần để chạy trong image, copy vào `/opt/scripts/` (chmod 755, đã có trong `PATH`, gọi thẳng theo tên). File `.sh` bắt buộc line ending LF (đã ép bằng [.gitattributes](.gitattributes)).

| Script | Mục đích |
|---|---|
| `00-entrypoint.sh` | Entrypoint: khởi tạo dữ liệu bind mount, cài memory-hub nếu thiếu, cài Java/Maven nếu bật, rồi `exec` CMD |
| `10-install-java-maven.sh` | Cài Java + Maven theo yêu cầu (xem mục Java & Maven) |

## 4. Yêu cầu tài khoản

- Tài khoản **Pro / Max / Team / Enterprise**. Team/Enterprise: Owner phải bật Remote Control trong admin settings.
- Đăng nhập bằng **claude.ai qua `claude auth login`**. Không dùng được:
  - `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `apiKeyHelper`
  - token từ `claude setup-token` / `CLAUDE_CODE_OAUTH_TOKEN` (thiếu scope Remote Control)
- Không đặt `ANTHROPIC_BASE_URL` khác `api.anthropic.com`, không dùng Bedrock/Vertex/Foundry.
- Không đặt `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` hoặc `DISABLE_GROWTHBOOK`.

> ⚠️ `settings.json` dựng sẵn đặt `DISABLE_TELEMETRY=1`. Theo tài liệu Claude Code, biến này cũng tắt việc tải feature flag. Chưa kiểm chứng nó có ảnh hưởng Remote Control hay không; nếu `claude doctor` báo lỗi eligibility, hãy bỏ biến này khỏi `include/.claude/settings.json`.

## 5. Chạy nhanh

### 5.0 Khởi tạo data (lần đầu)

```bash
cp .env.example .env                                  # điền giá trị thật
mkdir -p data/workspace data/claude-config data/claude-memory-hub
```

`settings.json`, commands, cấu hình MCP, hook và runtime claude-memory-hub sẽ được `00-entrypoint.sh` tự chép vào `data/` ở lần chạy đầu, không cần làm tay.

### Bước 1. Đăng nhập (một lần)

Mở shell bash trong container rồi login bên trong (chạy thẳng `claude auth login` qua `docker compose run` dễ lỗi `Login failed: Request failed with status code 400` khi dán code):

```bash
docker compose run --rm claude-rc bash
claude auth login                                     # chọn claude.ai → mở URL → dán code
exit
```

Login lưu ở `/home/node/.claude`, không cần login lại khi rebuild/restart.

### Bước 2. Chạy lần đầu tương tác

```bash
docker compose run --rm claude-rc
```

- `Trust /workspace? [y/N]` → `y`
- `Enable Remote Control? (y/n)` → `y`

Thấy URL session → `Ctrl+C`. Lựa chọn đã được lưu.

### Bước 3. Chạy nền

```bash
docker compose up -d
docker attach claude-rc       # xem URL, Space = QR; thoát không tắt container: Ctrl+P rồi Ctrl+Q
```

Mở **claude.ai/code** hoặc app Claude → tab **Code** → chọn session `Docker RC` (icon máy tính, chấm xanh).

## 6. Public review qua localtunnel

Container không publish port. Khi cần cho người khác xem app đang chạy trong container, dùng `/rc-localtunnel` trong session Claude:

```text
/rc-localtunnel 3000
/rc-localtunnel npm run dev -- --port 3000
/rc-localtunnel                      # Claude tự dò app/port trong project
```

Claude sẽ:

1. Chạy app nền (hoặc dùng app đã chạy sẵn), chờ app sẵn sàng.
2. Chạy `lt --port <port>`, trả về URL `https://xxxx.loca.lt` và **tunnel password** (IP public của container, lấy từ `https://loca.lt/mytunnelpassword`; nhập ở trang chặn đầu tiên của loca.lt).
3. Chờ bạn review.
4. Khi bạn báo xong → **tắt localtunnel và app** (app chỉ tắt nếu do Claude khởi động), kiểm tra port đã giải phóng.

Lưu ý:
- Tunnel là **công khai**: ai có URL + password đều truy cập được. Không dùng cho app có dữ liệu nhạy cảm mà không có đăng nhập.
- Dev server có kiểm tra host (Vite `allowedHosts`, webpack...) cần cho phép `*.loca.lt`.
- Chỉ tunnel đúng port cần review, không tunnel DB/SSH.

Dùng tay: `docker compose exec claude-rc bash` rồi `lt --port 3000` (Ctrl+C để tắt).

## 7. Vận hành

| Việc | Lệnh |
|---|---|
| Xem log | `docker compose logs -f` |
| Kiểm tra lỗi eligibility | `docker compose exec claude-rc claude doctor` |
| Cập nhật Claude Code | Đổi sang tag image mới (build từ GitHub Actions) rồi `docker compose pull && docker compose up -d` |
| Cập nhật claude-memory-hub | `docker compose exec claude-rc bunx claude-memory-hub@latest install` |
| Login lại | `docker compose exec claude-rc bash` → `claude auth logout` → `claude auth login` |
| Debug kết nối | Thêm `--verbose` vào `command` |

- Khi restart, `claude remote-control` **mang lại session cũ** nếu trong ~4 giờ (cùng thư mục, volume config còn nguyên).
- Server mode tự thoát sau ~10 phút mất mạng; `restart: unless-stopped` dựng lại.
- Auto-update của Claude Code có thể không chạy vì bản cài global thuộc root còn container chạy user `node`; cập nhật bằng cách dùng image mới.
- Cập nhật runtime memory-hub: nếu `data/claude-memory-hub` đã có runtime cũ, entrypoint không ghi đè; chạy lệnh `install` ở bảng trên.

## 8. Lưu ý

- **Quyền file**: container chạy user `node` (UID 1000). Nếu thư mục host thuộc UID khác, `chown 1000:1000` hoặc build lại với user phù hợp.
- **Git trong container**: mount `~/.gitconfig` và `~/.ssh` (read-only) nếu muốn Claude commit/push.
- **MCP server cục bộ**: phải chạy được *bên trong* container (cài thêm runtime vào Dockerfile nếu cần).
- **Không commit** `.env` và `data/` (login, workspace, DB bộ nhớ). Chỉ `.env.example` được theo dõi.
- **Bảo mật**: ai đăng nhập được tài khoản claude.ai của bạn là điều khiển được container này. Cân nhắc bật *Require trusted devices* trong Account settings. Hạn chế volume mount; tránh `bypassPermissions` trừ khi container cô lập.
