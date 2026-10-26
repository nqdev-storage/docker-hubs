---
description: Public app đang chạy trong container qua localtunnel để người dùng review từ xa, review xong thì tắt app + tunnel
argument-hint: [port | lệnh chạy app, ví dụ "3000" hoặc "npm run dev -- --port 3000"]
allowed-tools: Bash
---

# Public review qua localtunnel

Container Docker Remote Control không publish port nào ra ngoài. Image đã cài sẵn `localtunnel` (lệnh `lt`), dùng nó để tạo URL public tạm thời cho app đang chạy trong container, để người dùng mở trên điện thoại/máy khác review.

Đầu vào từ người dùng (có thể trống): `$ARGUMENTS`

## Quy trình

### 1. Xác định app và port

- Nếu `$ARGUMENTS` là một số → đó là port của app (app có thể đã chạy sẵn, kiểm tra ở bước 2).
- Nếu `$ARGUMENTS` là một lệnh → dùng lệnh đó để chạy app.
- Nếu trống → tự nhận diện từ project (`package.json` scripts, `vite.config.*`, `next.config.*`, `manage.py`, `Dockerfile`, ...) và nói rõ port đã chọn. Chỉ hỏi lại người dùng khi không đoán được.

### 2. Chạy app ở background

- Chạy app **nền**, ghi log ra file và lưu PID để tắt sau:

```bash
mkdir -p /tmp/rc-review
nohup <lệnh chạy app> > /tmp/rc-review/app.log 2>&1 &
echo $! > /tmp/rc-review/app.pid
```

- Nếu app đã chạy sẵn (port đã listen) thì **không chạy lại**, và ghi nhớ là app này không do bạn khởi động → khi dọn dẹp **không được kill nó**.
- Chờ app sẵn sàng trước khi mở tunnel:

```bash
for i in $(seq 1 30); do curl -s -o /dev/null "http://localhost:<port>" && break; sleep 1; done
```

- Nếu sau 30 giây vẫn không lên → đọc `/tmp/rc-review/app.log`, báo lỗi, dọn dẹp (bước 5) rồi dừng.
- App cần lắng nghe được trên `localhost` (nên bind `0.0.0.0` hoặc `127.0.0.1`). Với dev server có kiểm tra host (Vite `server.allowedHosts`, webpack `allowedHosts`, Next...), thêm cấu hình/flag cho phép host `*.loca.lt`, nếu không trang sẽ bị chặn khi truy cập qua tunnel.

### 3. Mở localtunnel

```bash
nohup lt --port <port> > /tmp/rc-review/lt.log 2>&1 &
echo $! > /tmp/rc-review/lt.pid
sleep 5
cat /tmp/rc-review/lt.log     # dòng "your url is: https://xxxx.loca.lt"
```

- Muốn subdomain cố định (nếu rảnh): thêm `--subdomain <tên>`. Không đảm bảo được cấp, nếu bị trùng thì dùng URL ngẫu nhiên.
- Nếu `lt.log` chưa có URL → đợi thêm vài giây, thử lại tối đa 3 lần. Vẫn lỗi → báo lỗi, dọn dẹp rồi dừng.
- Lấy **tunnel password** (trang đầu của loca.lt yêu cầu nhập, chính là IP public của container):

```bash
curl -s https://loca.lt/mytunnelpassword
```

### 4. Gửi thông tin cho người dùng

Trả về ngắn gọn:

- URL public (`https://xxxx.loca.lt`)
- Tunnel password (IP public ở trên) — người dùng nhập ở trang chặn đầu tiên của loca.lt
- Port và app đang chạy
- Nhắc: tunnel là **công khai**, ai có URL + password đều truy cập được → không chạy khi app chứa dữ liệu nhạy cảm/không có đăng nhập mà chưa được người dùng đồng ý.

Sau đó **dừng lại và chờ** người dùng review xong (họ sẽ báo "xong", "ok", "tắt đi", ...). Không tự tắt tunnel khi chưa được báo, trừ khi gặp lỗi.

### 5. Dọn dẹp — BẮT BUỘC sau khi review xong

Khi người dùng báo review xong, hoặc khi có lỗi/hủy giữa chừng, luôn tắt **cả localtunnel lẫn app** (app chỉ tắt nếu do bạn khởi động ở bước 2):

```bash
# Tắt localtunnel
[ -f /tmp/rc-review/lt.pid ] && kill "$(cat /tmp/rc-review/lt.pid)" 2>/dev/null
pkill -f "lt --port" 2>/dev/null

# Tắt app (chỉ khi do mình khởi động)
[ -f /tmp/rc-review/app.pid ] && kill "$(cat /tmp/rc-review/app.pid)" 2>/dev/null

# Dọn file tạm
rm -rf /tmp/rc-review
```

- `kill` theo PID có thể chỉ giết shell/wrapper (ví dụ `npm run dev` còn để lại process con). Sau khi kill, kiểm tra port đã được giải phóng:

```bash
curl -s -o /dev/null "http://localhost:<port>" && echo "VẪN CÒN CHẠY" || echo "đã tắt"
```

  Nếu vẫn còn chạy → tìm và kill process con (`pgrep -af <tên lệnh>`, hoặc `kill -- -<pgid>`), rồi kiểm tra lại.
- Xác nhận `pgrep -af "lt --port"` không còn kết quả.
- Báo lại cho người dùng: đã tắt localtunnel, đã tắt app (hoặc "app chạy sẵn từ trước nên giữ nguyên").

## Quy tắc

- Luôn chạy app và `lt` ở **background** (`nohup ... &`), không chạy foreground làm treo phiên.
- Mỗi lần chỉ mở tunnel cho đúng port cần review; không tunnel các port khác (DB, Redis, SSH...).
- Không tự ý để tunnel chạy lâu: hết review là tắt.
- Không in/commit secrets (token, `.env`) trong quá trình này.
