---
mode: post
type: bug-fix
status: completed
priority: medium
complexity: low
impact: medium
related_issues: [QUYIT-1120]
related_prs: []
estimated_hours:
time_spent_hours: 0.25
completed_date: 2026-11-25
---

# Nhật ký: Nâng Claude Code trong claude-rc lên 2.1.332, ghim version qua build arg

> **Ngày:** 2026-11-25
> **Phạm vi:** `claude-rc/` (Dockerfile, VERSION, README.md), `.github/workflows/claude-rc-docker-publish.yml`

## 1. Bối cảnh

Yêu cầu: cài bản Claude Code mới nhất vào image `claude-rc`. Bản mới nhất trên npm lúc làm là `2.1.332`, trong khi `claude-rc/VERSION` đang là `2.1.308`.

Khi khảo sát thì thấy một lỗi có sẵn. Dockerfile chạy `npm install -g @anthropic-ai/claude-code` mà không ghim phiên bản. CI build với `cache-from/cache-to type=registry ... mode=max`, nên lệnh RUN không đổi thì layer này lấy lại từ cache. Kết quả là image mới vẫn chứa Claude Code cũ, dù đã bump `VERSION`. Build arg `CLAUDE_CODE_VERSION` có khai báo trong Dockerfile nhưng chưa được dùng ở đâu.

## 2. Công việc đã thực hiện

1. **Khảo sát `claude-rc/`**: đọc Dockerfile, VERSION, docker-compose.yml, README, workflow CI; chạy `npm view @anthropic-ai/claude-code version` → `2.1.332`. Xác nhận quy ước: `VERSION` = phiên bản Claude Code, tag image = `<VERSION>-rc<run_number>`.
2. **Ghim phiên bản qua build arg**:
   - Dockerfile: `npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}`. Khi giá trị arg đổi, lệnh RUN đổi theo, nên layer được build lại thay vì lấy từ cache.
   - CI truyền `CLAUDE_CODE_VERSION=<VERSION>`. Như vậy `VERSION` là nơi duy nhất cần sửa để nâng phiên bản.
   - Arg mặc định vẫn là `latest`, để build tay không truyền arg vẫn chạy được như trước.
   - Phương án đã loại: ghi cứng `2.1.332` làm giá trị mặc định trong Dockerfile. Cách này phải sửa hai nơi (Dockerfile và VERSION) mỗi lần nâng, dễ lệch nhau.
3. **Bump `VERSION`** `2.1.308` → `2.1.332`, cập nhật README (bảng package, bảng build arg, lệnh build tay).
4. **Verify**: `docker compose config -q` OK; build local với `--build-arg CLAUDE_CODE_VERSION=$(cat VERSION)` thành công (~254s); `claude --version` trong container → `2.1.332 (Claude Code)`.

Giữ nguyên: `docker-compose.yml` vẫn trỏ image `ghcr.io/nqdev-storage/claude-rc:2.1.306-rc6-manual`. Chưa sửa vì tag mới có `-rc<run_number>`, chỉ biết sau khi CI chạy xong.

## 3. Files đã thay đổi

| File | Thay đổi |
|---|---|
| [claude-rc/Dockerfile](../claude-rc/Dockerfile) | `npm install` dùng `@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}`, thêm comment `[nqdev]` giải thích lý do |
| [claude-rc/VERSION](../claude-rc/VERSION) | `2.1.308` → `2.1.332` |
| [claude-rc/README.md](../claude-rc/README.md) | Mô tả cơ chế ghim version, thêm `CLAUDE_CODE_VERSION` vào bảng build arg và lệnh build tay, bỏ ghi chú "chưa được dùng" |
| [.github/workflows/claude-rc-docker-publish.yml](../.github/workflows/claude-rc-docker-publish.yml) | `build-args` thêm `CLAUDE_CODE_VERSION` lấy từ file `VERSION` |

## 4. Trạng thái hiện tại

Đã commit `d0fd8f5` và push lên `develop`. CI chạy tay (`workflow_dispatch`, workflow không tự chạy khi push) đã build image `ghcr.io/nqdev-storage/claude-rc:2.1.332-rc11-manual`. `docker-compose.yml` đã trỏ sang tag này.

## 5. Việc còn mở

- [x] Commit và push (`d0fd8f5`)
- [x] Cập nhật `image:` trong [claude-rc/docker-compose.yml](../claude-rc/docker-compose.yml) sang `2.1.332-rc11-manual`
- [ ] Xóa image test local: `docker rmi claude-rc:test`
- [ ] Recreate container trên máy chạy RC để dùng image mới (`docker compose up -d --force-recreate`)

## 6. Bài học rút ra

Khi CI dùng registry build cache, lệnh cài package không ghim phiên bản (`npm install -g pkg`) sẽ bị cache vô thời hạn. Muốn nâng phiên bản thì phải để chuỗi phiên bản xuất hiện trong chính lệnh RUN, thông qua build arg.

## Tiến độ

| # | Bước | Trạng thái | Bắt đầu | Kết thúc | Delta (phút) | Ghi chú |
|---|---|---|---|---|---|---|
| 1 | Khảo sát claude-rc, phát hiện lỗi cache | xong | 2026-11-25 10:40 | 2026-11-25 10:45 | 5 | |
| 2 | Ghim version qua build arg, sửa CI/README/VERSION | xong | 2026-11-25 10:45 | 2026-11-25 10:50 | 5 | |
| 3 | Validate compose, build và kiểm tra version | xong | 2026-11-25 10:50 | 2026-11-25 10:57 | 7 | |
| 4 | Commit, push, cập nhật tag image trong compose | xong | 2026-11-25 11:07 | 2026-11-25 11:10 | 3 | |
| 4 | (tiếp) | xong | 2026-11-25 11:20 | 2026-11-25 11:22 | 2 | |
| **Tổng** | | | | | **22** | = 0.25h |
