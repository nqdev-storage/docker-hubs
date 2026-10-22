# Claude Code Remote Control trong Docker

Chạy `claude remote-control` (server mode) trong container, điều khiển từ claude.ai/code hoặc app Claude trên điện thoại.

## Yêu cầu bắt buộc (theo docs)

- Tài khoản **Pro / Max / Team / Enterprise**. Team/Enterprise: Owner phải bật toggle Remote Control trong admin settings.
- Đăng nhập bằng **claude.ai qua `claude auth login`**. Không dùng được:
  - `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `apiKeyHelper`
  - token từ `claude setup-token` / `CLAUDE_CODE_OAUTH_TOKEN` (token này thiếu scope cho Remote Control)
- Không đặt `ANTHROPIC_BASE_URL` khác `api.anthropic.com`, không dùng Bedrock/Vertex/Foundry.
- Không đặt `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` hoặc `DISABLE_GROWTHBOOK`.
- Container chỉ cần **outbound HTTPS 443** — không cần mở port nào.

## Cài đặt

```bash
mkdir -p workspace            # hoặc sửa volume trỏ tới repo thật
docker compose build
```

### 1. Đăng nhập (một lần)

Mở shell bash trong container trước, rồi mới chạy login bên trong (chạy thẳng `claude auth login` qua `docker compose run` dễ bị lỗi `Login failed: Request failed with status code 400` khi dán code):

```bash
docker compose run --rm --entrypoint bash claude-rc
```

Sau khi vào được shell của container, chạy:

```bash
claude auth login
```

Chọn đăng nhập bằng claude.ai → mở URL được in ra trên trình duyệt máy bạn → dán code trả về vào terminal → xong gõ `exit` để thoát.
Thông tin đăng nhập lưu trong volume `claude-config`, nên không cần login lại khi rebuild/restart.

### 2. Chạy lần đầu ở chế độ tương tác (để trả lời 2 prompt)

```bash
docker compose run --rm claude-rc
```

- `Trust /workspace? [y/N]` → `y`
- `Enable Remote Control? (y/n)` → `y`

Thấy URL session là OK → `Ctrl+C` để thoát. Lựa chọn đã được lưu.

> Nếu bỏ qua bước này mà chạy `up -d` luôn thì vẫn được (có TTY), nhưng phải `docker attach` vào để trả lời prompt.

### 3. Chạy nền

```bash
docker compose up -d
docker attach claude-rc       # xem URL, nhấn SPACE để hiện QR code
                              # thoát mà không tắt container: Ctrl+P rồi Ctrl+Q
```

Sau đó mở **claude.ai/code** hoặc app Claude → tab **Code** → chọn session `Docker RC` (icon máy tính, chấm xanh).

## Vận hành

| Việc | Lệnh |
|---|---|
| Xem log | `docker compose logs -f` |
| Kiểm tra lỗi eligibility | `docker compose exec claude-rc claude doctor` |
| Cập nhật Claude Code | `docker compose build --no-cache && docker compose up -d` |
| Login lại (đổi plan / lỗi entitlement) | `docker compose exec claude-rc bash` rồi trong shell chạy `claude auth logout` và `claude auth login` |
| Debug kết nối | thêm `--verbose` vào `command` |

- Khi container restart, `claude remote-control` sẽ **mang lại các session cũ** nếu trong vòng ~4 giờ (cùng thư mục, volume config còn nguyên).
- Server mode tự thoát sau ~10 phút mất mạng; `restart: unless-stopped` sẽ dựng lại.
- `--spawn worktree`: mỗi session mới có git worktree riêng, tránh đụng file — cần `/workspace` là git repo.
- `--capacity N`: giới hạn số session đồng thời (mặc định 32).

## Lưu ý

- **Quyền file**: container chạy user `node` (UID 1000). Nếu thư mục project trên host thuộc UID khác, `chown 1000:1000` hoặc build lại với user phù hợp.
- **Git trong container**: mount `~/.gitconfig` và `~/.ssh` (read-only) nếu muốn Claude commit/push.
- **MCP server cục bộ**: chúng phải chạy được *bên trong* container (cài thêm runtime vào Dockerfile nếu cần).
- **Bảo mật**: ai đăng nhập được tài khoản claude.ai của bạn là điều khiển được container này. Cân nhắc bật *Require trusted devices* trong Account settings. Hạn chế volume mount ở mức cần thiết; tránh `bypassPermissions` trừ khi container thật sự cô lập.