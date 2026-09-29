# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay mỗi dòng trả lời mẫu bằng câu trả lời của chính bạn.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Văn Thân  Mã học viên: 2A202602859

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Khi tôi deploy lên Render và quên set `AGENT_API_KEY` trong dashboard, app chết ngay lúc container khởi động: log hiện `pydantic_core.ValidationError: Field required` rồi container exit, Render báo deploy failed và tôi biết ngay trong 30 giây đầu. Nếu để mặc định `"changeme"`, app vẫn khởi động, vẫn trả 200 ở `/health`, Render báo deploy thành công — nhưng bất kỳ ai đoán được khóa `changeme` đều gọi `/ask` miễn phí bằng ngân sách của tôi. Tôi chỉ phát hiện khi nhìn hóa đơn, lúc đó tiền đã mất và không biết ai đã dùng. Chết sớm biến một sự cố âm thầm kéo dài thành một lỗi ồn ào ngay trước mắt, lúc tôi còn đang ngồi trước màn hình để sửa.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Log thật lấy từ `docker logs` khi chạy stack:

```json
{"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T03:25:22.391861+00:00", "user_id": "sv-ratelimit", "tokens_in": 302, "tokens_out": 43, "cost_usd": 7.11e-05}
```

Hai việc làm được mà `print("đã trả lời xong")` không làm được:

1. **Lọc và tổng hợp theo trường**: vì mỗi dòng là một JSON object có khóa cố định, tôi parse được bằng `jq`/Datadog để trả lời "user nào tiêu nhiều tiền nhất hôm nay?" (`group by user_id | sum cost_usd`). Chuỗi `"đã trả lời xong"` không có trường nào để nhóm hay cộng.
2. **Đặt cảnh báo theo ngưỡng**: `cost_usd` và `tokens_in` là số, nên tôi cấu hình cảnh báo "báo tôi khi tổng `cost_usd` 5 phút qua vượt 1 USD" hoặc "khi tỷ lệ lỗi tăng". Log văn bản tự do không có cấu trúc để máy so sánh ngưỡng.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ... MB |
| Multi-stage | ... MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Số đo thật, build trên server Linux (Docker 26.1.3):

```
$ docker images --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep agent:
agent:multi   206MB
agent:single  1.19GB
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu, `Dockerfile.single-stage`) | 1190 MB |
| Multi-stage (`Dockerfile`) | 206 MB |

Phần chênh lệch ~984 MB chủ yếu là: (1) **base image đầy đủ** `python:3.11` mang theo cả toolchain biên dịch (gcc, make, header dev) và nhiều thư viện hệ thống mà bản `slim` cắt bỏ; (2) **cache pip và wheel tải về** nằm lại trong layer `RUN pip install` của bản 1-stage; (3) **source code, `.git`, `tests/`** bị `COPY . .` mang vào image (bản multi-stage chỉ `COPY app` và `utils`). Multi-stage để lại toàn bộ compiler và cache đó trong stage `builder` rồi vứt đi, chỉ copy đúng thư mục `/opt/venv` sang stage runtime.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

Khi tôi sửa một ký tự trong `app/main.py` rồi build lại:

- **Dùng lại từ cache**: `FROM python:3.11-slim`, `COPY requirements.txt`, `RUN python -m venv && pip install -r requirements.txt` — tất cả vẫn nguyên vì `requirements.txt` không đổi. Layer cài thư viện (nặng nhất, vài chục giây) được dùng lại.
- **Phải chạy lại**: `COPY app ./app` và `COPY utils ./utils` (nội dung đổi) cùng mọi layer sau nó — `RUN useradd` và metadata.

Nếu đặt `COPY . .` **trước** `RUN pip install`, thì mỗi lần sửa một dòng code, layer `COPY . .` đổi → cache của mọi layer sau nó bị vô hiệu → Docker phải **cài lại toàn bộ thư viện từ đầu** mỗi lần build. Đó chính là lý do thứ tự `COPY requirements.txt` → `pip install` → `COPY source` quan trọng: nó tách thứ ít đổi (danh sách thư viện) ra khỏi thứ đổi liên tục (source code).

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Chuỗi sự kiện:

1. Code Python của tôi có lỗ hổng (ví dụ deserialization không an toàn, hoặc một dependency có CVE cho phép thực thi lệnh).
2. Kẻ tấn công khai thác lỗ hổng đó qua endpoint công khai và chạy được lệnh **bên trong container**.
3. Vì container chạy bằng **root (UID 0)**, lệnh đó có toàn quyền trong container.
4. Nếu container có mount volume từ host, socket Docker, hoặc kernel có lỗ hổng thoát container (container escape), quyền root trong container trở thành **quyền root trên máy host** — kẻ tấn công đọc được mọi file, cài backdoor, chiếm cả server.

Lệnh `USER appuser` cắt chuỗi đó ở **bước 3**: kể cả khi kẻ tấn công chạy được lệnh trong container, tiến trình chỉ có quyền của user thường. Họ không ghi được vào `/etc`, không cài package, không đọc file của root, và mọi bước leo thang đặc quyền sau đó đều khó hơn nhiều. Container chạy root biến một lỗ hổng nhỏ thành quyền cao nhất; `USER` giới hạn thiệt hại ở mức thấp nhất.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Với cách đếm theo phút đồng hồ (reset lúc giây 00), người dùng có thể gửi **20 request trong 2 giây** khi hạn mức là 10/phút.

Cách đạt được: hạn mức được tính lại ở mốc `10:00:00`. Người dùng dồn 10 request vào **cuối** phút trước — `10:00:59` — rồi 10 request vào **đầu** phút sau — `10:01:01`. Cả hai lần đều nằm trong hai "cửa sổ phút" khác nhau, mỗi cửa sổ chỉ có 10 request nên hợp lệ. Nhưng thực tế chỉ 2 giây trôi qua giữa request đầu và request cuối, và hệ thống vừa nhận 20 request — gấp đôi hạn mức.

Sliding window 60 giây tránh được lỗ hổng này vì nó luôn nhìn lại đúng 60 giây **gần nhất** so với thời điểm hiện tại, chứ không quan tâm mốc đồng hồ. Ở ví dụ trên, tại `10:01:01` cửa sổ trượt bao trùm cả 10 request lúc `10:00:59`, nên request thứ 11 bị chặn 429 ngay.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

Hai cơ chế khác nhau ở **đại lượng chúng giới hạn**:

- **Rate limit** giới hạn *tốc độ*: số request trong một đơn vị thời gian (10/phút). Nó chống lạm dụng và bảo vệ hạ tầng khỏi bị dội request.
- **Cost guard** giới hạn *số tiền*: tổng chi phí trong một tháng (10 USD). Nó chống việc tiêu quá ngân sách, bất kể tốc độ.

**Rate limit cho qua nhưng cost guard phải chặn**: user gửi đúng 10 request/phút — không vi phạm rate limit — nhưng mỗi request đẩy vào một prompt 50.000 token. Sau vài chục request họ đã tiêu hết 10 USD ngân sách tháng. Rate limit không thấy gì bất thường (đúng 10/phút), nhưng cost guard phải trả 402.

**Cost guard cho qua nhưng rate limit phải chặn**: user mới, chưa tiêu đồng nào (`spent = 0`, còn nguyên ngân sách), nhưng bấm gửi liên tục 100 request/giây bằng script. Cost guard thấy còn tiền nên cho qua, nhưng rate limit phải trả 429 để không đánh sập service.

Vì hai cơ chế bắt hai loại vấn đề khác nhau, `/ask` kiểm tra **cả hai** trước khi gọi LLM.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Nếu gộp `/health` và `/ready` làm một và cho nó kiểm tra Redis, khi Redis mất kết nối 30 giây thì thứ tự sự kiện với cụm 3 container là:

1. Redis ngừng trả lời.
2. Cả 3 container gọi endpoint gộp đó, `store.ping()` trả `False` → endpoint trả **503**.
3. Orchestrator (Docker, Railway, Cloud Run, K8s) đọc 503 của **liveness probe** và hiểu là "process này hỏng, cần restart".
4. Orchestrator **restart cả 3 container** cùng lúc.
5. Container khởi động lại, nhưng Redis vẫn chưa sống → endpoint vẫn 503 → orchestrator lại restart. Vòng lặp restart (crashloop) diễn ra liên tục trong suốt 30 giây đó.
6. Trong lúc restart, cả 3 instance đều không phục vụ được request nào — kể cả những request lẽ ra vẫn chạy tốt (như `/health` hay `/ask` cho user đã có lịch sử). Một sự cố Redis 30 giây bị biến thành **sự cố toàn hệ thống kéo dài hơn thế**.

Đó là lý do tách hai endpoint: `/health` (liveness) **không** chạm Redis — Redis chết thì process vẫn sống, không cần restart. `/ready` (readiness) mới kiểm tra Redis và trả 503 để load balancer **tạm ngừng đẩy traffic** vào instance đó, chứ không restart nó. Khi Redis trở lại, instance vẫn nguyên vẹn và nhận traffic ngay, không mất thời gian khởi động lại.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Khi chạy `docker compose up --scale agent=3` và gọi `/ask` nhiều lần với cùng một `X-User-Id`, `history_length` **tăng đều và liên tục**: 0, 2, 4, 6, ... bất kể request rơi vào container nào.

Lý do: lịch sử nằm trong **Redis**, là nơi cả 3 container cùng đọc/ghi. Container A ghi lượt hỏi và lượt trả lời vào Redis, container B hay C đọc lại thấy đủ. Load balancer chia request thế nào cũng không ảnh hưởng — state không thuộc về container nào.

Nếu lịch sử được lưu trong một **dict Python** trong RAM của mỗi instance, con số sẽ **nhảy lung tung và không bao giờ đủ**: mỗi container có dict riêng, nên request rơi vào container đã thấy lượt trước thì `history_length` tăng, rơi vào container mới (chưa từng nhận request nào của user này) thì lại về **0**. Chuỗi quan sát được sẽ giống `0, 2, 0, 2, 4, 0, ...` tùy load balancer chia thế nào. Đây chính là hiện tượng "agent mất trí nhớ" — và cũng là lý do state phải đưa ra khỏi process để scale ngang được.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

Lỗi tôi gặp khi deploy Render: **build thành công nhưng health check timeout, Render báo "Deploy failed"**.

Thông báo trên dashboard: `Health check failed for /health after 30 seconds` và service bị đánh dấu unhealthy. Xem tab Logs thì thấy container chạy tới dòng `Uvicorn running on http://0.0.0.0:8000` nhưng Render vẫn không gọi vào được.

Cách tìm nguyên nhân: tôi đối chiếu với gợi ý trong `LAB_GUIDE.md` — "app đang bind `127.0.0.1` hoặc cố định cổng 8000 thay vì đọc `$PORT`". Kiểm tra lại `CMD` trong Dockerfile, tôi thấy bản đầu hardcode `--port 8000`. Render gán cổng động qua biến `$PORT` (thường không phải 8000), nên app listen ở cổng 8000 trong khi Render chờ ở cổng nó gán → không kết nối được.

Cách sửa: đổi `CMD` thành đọc `$PORT`:

```dockerfile
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
```

`0.0.0.0` để nhận kết nối từ ngoài container, `${PORT:-8000}` để lấy cổng platform gán và chỉ rơi về 8000 khi chạy ở máy (không có `$PORT`). Sau khi push lại, health check `/health` trả 200 và deploy thành công. Tôi cũng thêm `healthcheckPath = "/health"` vào `railway.toml`/`render.yaml` để platform biết chờ đúng endpoint.
