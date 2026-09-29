# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Nguyễn Văn Thân |
| Mã học viên | 2A202602859 |
| Repo | https://github.com/meth04/K4-L3B-DAY12-NguyenVanThan-2A202602859-CloudServicesAndDeployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://day12-agent-hbvb.onrender.com |
| Platform | Render |
| Ngày deploy | 2026-09-29 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán (Render inject) |
| `AGENT_API_KEY` | ✅ | đặt trong dashboard, không nằm trong repo |
| `REDIS_URL` | ✅ | Redis add-on của Render (`day12-redis`, plan free), nối qua internal connection string |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Dán output của các lệnh trên vào đây:

```
$ curl -i https://day12-agent-hbvb.onrender.com/health
HTTP/2 200
content-type: application/json
server: cloudflare
date: Tue, 29 Sep 2026 03:52:12 GMT

{"status":"ok","service":"day12-agent","version":"1.0.0"}

$ curl -i https://day12-agent-hbvb.onrender.com/ready
HTTP/2 200
content-type: application/json
server: cloudflare
date: Tue, 29 Sep 2026 03:52:12 GMT

{"status":"ready","redis":true}

$ curl -i -X POST https://day12-agent-hbvb.onrender.com/ask \
    -H "Content-Type: application/json" -d '{"question":"Hello"}'
HTTP/2 401
content-type: application/json
date: Tue, 29 Sep 2026 03:52:12 GMT

{"detail":"invalid or missing API key"}

$ curl -i -X POST https://day12-agent-hbvb.onrender.com/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" -H "X-User-Id: sv-test" \
    -d '{"question":"Deploy là gì?"}'
HTTP/2 200
content-type: application/json

{
  "answer": "Ngắn gọn: Deploy la gi phụ thuộc vào ba yếu tố — cấu hình qua biến môi trường, health check để orchestrator biết trạng thái, và giới hạn tài nguyên.",
  "user_id": "sv-test",
  "history_length": 0,
  "cost_usd": 2.265e-05,
  "tokens": {"in": 3, "out": 37}
}

$ for i in $(seq 1 15); do curl -s -o /dev/null -w "%{http_code} " -X POST .../ask \
    -H "X-API-Key: $AGENT_API_KEY" -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'; done; echo
200 200 200 200 200 200 200 200 200 429 429 429 429 429 429
```

Nhận xét: 9 request đầu trả `200`, 6 request sau trả `429`. Con số 9 (không
phải 10) là vì lệnh 4 ngay trước đó cũng dùng `X-User-Id: sv-test` và đã tiêu
1 lượt — sliding window 60 giây đếm chung, đúng như thiết kế.

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên platform (Render)
- `screenshots/health.png` — kết quả gọi `/health` từ trình duyệt (liveness)
- `screenshots/ready.png` — kết quả gọi `/ready`, trả `{"status":"ready","redis":true}`
  — bằng chứng service trên cloud đã nối được Redis add-on

---

## Ghi Chú Thêm

- Service tạo bằng Render API v1 (`POST /services` + `POST /redis`), region
  `oregon`, plan `free`. Build từ `Dockerfile` ở nhánh `main`.
- `AGENT_API_KEY` do Render giữ, chỉ tồn tại trong dashboard và trong `.env`
  cục bộ — **không** có trong repo.
- Render inject biến `PORT`; `CMD` trong Dockerfile đọc `${PORT:-8000}` nên
  container listen đúng cổng platform gán.
- Health check của Render trỏ vào `/health` (liveness, không phụ thuộc Redis).
