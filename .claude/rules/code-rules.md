# Code Rules

## Testing Rules

1. Không dùng số điện thoại thật khi test. Chỉ dùng các số test được phép: `0909090909`, `0765418062`.
2. Với Docker/compose: kiểm tra bằng `docker compose config` (validate cú pháp) và build thử trước khi báo hoàn thành; không `down -v` trên môi trường có dữ liệu thật (mất login / DB bộ nhớ).

## Comment Rule

Comment của agent thêm vào phải gắn label của dev đang chạy session, lấy từ `.claude/dev.local.json` (`label`). Nếu chưa có file/label: gợi ý từ `git config user.name`/`user.email`, hỏi dev xác nhận 1 lần rồi lưu lại.

Định dạng: `<cú-pháp-comment> [<label>] <WHY>` — ví dụ `# [nqdev] ...` (Dockerfile, YAML, shell), `// [nqdev] ...`.

1. Chỉ comment khi logic phức tạp, workaround tạm, hoặc edge case đặc biệt.
2. Comment giải thích WHY, không giải thích WHAT.
3. Sửa code → sửa/xóa comment cũ theo, không để lỗi thời.
4. Code tự rõ nghĩa (CRUD đơn giản, tên biến/hàm rõ ràng) → không comment.

## Database Execution Policy

NOT run by Claude — cần DBA review

1. Claude/agent **không bao giờ** thực thi SQL trực tiếp lên bất kỳ database nào (dev, staging, production), dù qua CLI, ORM migration tool hay MCP DB connector.
2. Áp dụng cho mọi DDL (`CREATE`/`ALTER`/`DROP`/`TRUNCATE`), DML (`INSERT`/`UPDATE`/`DELETE`) và schema migration.
3. Khi cần thay đổi: viết câu SQL vào chat, gắn tag bên dưới rồi dừng — DBA review và tự chạy.
4. Ngoại lệ: `SELECT` chỉ-đọc để chẩn đoán được chạy trực tiếp.

```sql
-- NOT run by Claude — cần DBA review
ALTER TABLE orders ADD COLUMN shipped_at TIMESTAMP NULL;
```

## Git Commit Policy

1. KHÔNG tự ý `git commit` (kể cả `--amend`) — luôn hỏi và chờ dev xác nhận rõ ràng trước khi commit.
2. Khi hỏi, nêu rõ: danh sách file sẽ commit + message dự kiến.
3. Xác nhận cho 1 lần commit không áp dụng cho các lần sau — mỗi lần commit hỏi lại. Im lặng hoặc trả lời mơ hồ = chưa xác nhận.
4. Không tự `git push`, `git push --force`, `git reset --hard`, rebase, merge, tạo/xóa branch, tag nếu dev chưa yêu cầu.
5. Lệnh chỉ đọc (`status`, `diff`, `log`, `show`, `branch`) không cần xác nhận.
