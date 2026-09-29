# Hướng dẫn lấy Render API key (CP5)

Mục tiêu: lấy một API key để tôi tự tạo Blueprint (web service + Redis),
chờ build, lấy URL và chạy kiểm tra — bạn không phải bấm gì thêm.

---

## Bước 1 — Đăng nhập Render bằng GitHub

1. Mở https://dashboard.render.com/register
2. Chọn **GitHub** (không cần nhập email/mật khẩu riêng)
3. Render xin quyền đọc repo → bấm **Authorize Render**
4. Render **có thể** hỏi số điện thoại / thẻ để xác minh tài khoản. Free tier
   không bị trừ tiền, nhưng Render có thể yêu cầu thẻ để chống spam.
   - Nếu không có thẻ: dừng ở đây và báo tôi — ta chuyển phương án khác.

## Bước 2 — Tạo API key

1. Vào https://dashboard.render.com/u/settings#api-keys
   (hoặc: góc phải trên → **Account Settings** → tab **API Keys**)
2. Bấm **Create API Key**
3. **Name**: đặt gì cũng được, ví dụ `day12-lab`
4. **Expiration**: chọn **No expiration** (hoặc 1 ngày — tùy bạn)
5. Bấm **Create API Key**
6. Render hiện key **một lần duy nhất**, dạng `rnd_xxxxxxxxxxxxxxxxxxxx`.
   Copy ngay — đóng đi là không xem lại được.

## Bước 3 — Gửi key cho tôi

Dán key vào chat. Tôi sẽ:

1. Tạo Blueprint từ repo GitHub của bạn bằng `render.yaml` có sẵn
2. Sinh một `AGENT_API_KEY` mới và set vào service (không nằm trong repo)
3. Chờ build xong, lấy URL HTTPS
4. Chạy 5 lệnh kiểm tra trong `DEPLOYMENT.md`
5. Điền `DEPLOYMENT.md` + chụp màn hình vào `screenshots/`

---

## ⚠️ Đọc trước khi gửi key

- API key này cho phép **quản lý toàn bộ tài khoản Render** của bạn: tạo/xoá
  service, đọc biến môi trường, xem hoá đơn. Không chỉ repo này.
- Chỉ gửi nếu bạn thấy thoải mái. Nếu không, chọn cách khác:
  - **Bạn tự bấm Blueprint** (tôi hướng dẫn từng màn hình), hoặc
  - **Phương án server SSH** (đã chạy thật, nhưng URL là `http://` → CP5 còn
    14/15, tổng 99/100).
- Sau khi lab chấm xong, **xoá key** tại đúng trang ở Bước 2 để thu hồi.
- Key chỉ dùng trong phiên chat này; tôi sẽ không ghi key vào file nào trong repo.

---

## Nếu bạn chọn tự bấm (không gửi key)

1. Vào https://dashboard.render.com/blueprints
2. **New Blueprint Instance**
3. Chọn repo `K4-L3B-DAY12-NguyenVanThan-2A202602859-CloudServicesAndDeployment`
4. Render đọc `render.yaml`, hiện 2 service: `day12-agent` (web) + `day12-redis`
5. Render hỏi giá trị `AGENT_API_KEY` → dán một khóa bạn tự sinh:
   ```
   python -c "import secrets; print(secrets.token_urlsafe(32))"
   ```
6. Bấm **Apply** / **Create**
7. Chờ ~3–5 phút tới khi service **Live**, copy URL dạng
   `https://day12-agent-xxxx.onrender.com` rồi gửi tôi URL đó.
