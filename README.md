# docker-hubs

Tập hợp Docker image + compose tự dựng cho các công cụ AI coding, publish lên GHCR (`ghcr.io/nqdev-storage/*`). Mỗi image nằm trong một thư mục riêng, có `Dockerfile`, `docker-compose.yml`, `VERSION` và README chi tiết.

| Image | Mục đích | Version | Port host → container | Chi tiết |
|---|---|---|---|---|
| [`opencode`](opencode/) | [OpenCode](https://opencode.ai) server/web UI, thêm Python, Node.js, Chromium, Git và MCP Playwright | `2.4.1` | `10026 → 4096` | [opencode/README.md](opencode/README.md) |
| [`playwright-mcp`](playwright-mcp/) | MCP server Playwright độc lập (browser automation qua HTTP) | `1.40.0` | `40001 → 8931` | [playwright-mcp/README.md](playwright-mcp/README.md) |
| [`claude-rc`](claude-rc/) | Claude Code Remote Control (`claude remote-control`), điều khiển từ claude.ai/code hoặc app Claude | `2.1.332` | Không publish port (chỉ cần outbound 443) | [claude-rc/README.md](claude-rc/README.md) |

Version lấy từ file `VERSION` trong từng thư mục; tag image thực tế có thêm hậu tố build `-rcN` (xem [Publish image](#publish-image)).

## Chạy nhanh

Yêu cầu: Docker + Docker Compose. Lệnh chạy **trong thư mục của image**.

### opencode

```bash
cd opencode
cp .env.example .env        # đổi OPENCODE_SERVER_USERNAME / OPENCODE_SERVER_PASSWORD
docker-compose up -d --force-recreate --remove-orphans

# Web UI: http://localhost:10026
docker exec -it opencode-10029 script -q -c "bash"   # vào shell
docker logs opencode-10029 -f                       # xem log
docker-compose down --remove-orphans                # dừng
```

`docker-compose.yml` kéo image dựng sẵn trên GHCR, không build local. Container chạy `root` + `privileged: true` (cần cho MITM mạng).

### playwright-mcp

```bash
cd playwright-mcp
docker-compose up -d --build --force-recreate --remove-orphans
curl http://localhost:40001/mcp
```

Compose này **build local** từ `Dockerfile` (có thêm biến thể `Dockerfile.ultra-slim`, `Dockerfile.advanced-slim`).

### claude-rc

Lần đầu cần khởi tạo `data/` và đăng nhập `claude auth login`; làm theo [claude-rc/README.md §5](claude-rc/README.md#5-chạy-nhanh). Sau đó:

```bash
cd claude-rc
cp .env.example .env
docker-compose up -d
```

> Không đặt API key / base URL của Anthropic trong `.env`: Remote Control bắt buộc đăng nhập bằng tài khoản.

> **Cẩn thận với `down -v`**: xoá volume đồng nghĩa mất dữ liệu (login, cấu hình, bộ nhớ claude-memory-hub). Chỉ dùng khi chủ động muốn reset.

## Publish image

Mỗi image có một workflow GitHub Actions riêng, hiện **chỉ chạy tay** (`workflow_dispatch`, trigger theo tag `v*` đang tắt):

| Workflow | Image |
|---|---|
| [opencode-docker-publish.yml](.github/workflows/opencode-docker-publish.yml) | `ghcr.io/nqdev-storage/opencode` |
| [playwright-mcp-docker-publish.yml](.github/workflows/playwright-mcp-docker-publish.yml) | `ghcr.io/nqdev-storage/playwright-mcp` |
| [claude-rc-docker-publish.yml](.github/workflows/claude-rc-docker-publish.yml) | `ghcr.io/nqdev-storage/claude-rc` |

- Version đọc từ `<image>/VERSION`.
- Tag khi chạy tay: `{VERSION}-rc{RUN_NUMBER}-manual`. Khi bật lại trigger tag: `{VERSION}-rc{RUN_NUMBER}` + `latest`.
- Docker Hub (`quyit/*`) đang tắt trong workflow.
- Sau khi publish, cập nhật tag `image:` trong `docker-compose.yml` tương ứng.

[changelog.yml](.github/workflows/changelog.yml) chạy khi push tag `v*` (hoặc chạy tay) và cập nhật [CHANGELOG-NQDEV.md](CHANGELOG-NQDEV.md).

## Cấu trúc repo

```
docker-hubs/
├── opencode/          # Image OpenCode (Dockerfile, compose, preload/, data/)
├── playwright-mcp/    # Image Playwright MCP (3 biến thể Dockerfile)
├── claude-rc/         # Image Claude Code Remote Control (include/, scripts/, data/)
├── docs/              # Tài liệu nghiệp vụ (BUSINESS.md)
├── plans/             # Execution plan / nhật ký công việc
├── .github/
│   ├── workflows/     # Publish image + changelog
│   └── actions/set-version/
├── .version.txt       # Version chung của repo
├── AGENTS.md          # Kiến thức dự án cho AI agent / dev mới
└── CHANGELOG-NQDEV.md
```

Thư mục `data/` trong từng image là volume runtime (chứa login, cấu hình, bộ nhớ). Không commit thư mục này.

## Đóng góp

- Đọc [AGENTS.md](AGENTS.md) trước khi sửa: kiến trúc, lệnh, lưu ý.
- Quy tắc cho agent (comment, commit, test compose): [.claude/rules/code-rules.md](.claude/rules/code-rules.md).
- Kiểm tra compose trước khi báo xong: `docker compose config` rồi build/chạy thử.

## License

Apache License 2.0, xem [LICENSE](LICENSE).
