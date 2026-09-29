# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (production-ready)
#
# Multi-stage: stage `builder` cài dependency vào một venv riêng, stage
# runtime chỉ copy venv + source sang. Nhờ vậy image cuối không mang theo
# compiler, header, cache của pip — nhỏ hơn nhiều lần và ít bề mặt tấn công.
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# ─── Stage 1: builder ──────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /app

# COPY requirements.txt TRƯỚC khi COPY source: layer này chỉ đổi khi danh sách
# thư viện đổi, nên sửa một dòng code không phải cài lại toàn bộ dependency.
COPY requirements.txt .

# Cài vào venv riêng để stage runtime chỉ cần copy đúng thư mục đó.
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# ─── Stage 2: runtime ──────────────────────────────────────────────
FROM python:3.11-slim AS runtime

# Tắt .pyc và bật log không buffer để log JSON ra ngay, không bị giữ trong
# buffer khi container bị SIGKILL.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    PORT=8000

WORKDIR /app

# Chỉ lấy kết quả đã cài từ builder, không mang theo compiler/cache.
COPY --from=builder /opt/venv /opt/venv

# Source code copy SAU cùng để tận dụng cache của các layer trên.
COPY app ./app
COPY utils ./utils

# User thường: container chạy root nghĩa là ai thoát được khỏi app cũng thành
# root trên host. USER cắt chuỗi leo thang đặc quyền đó.
RUN useradd --create-home --shell /usr/sbin/nologin appuser
USER appuser

EXPOSE 8000

# HEALTHCHECK gọi /health — endpoint này cố tình không phụ thuộc Redis.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os,urllib.request,sys; \
sys.exit(0 if urllib.request.urlopen(f\"http://127.0.0.1:{os.environ.get('PORT','8000')}/health\", timeout=3).status == 200 else 1)"

# Đọc cổng từ $PORT: cloud tự gán cổng, không cố định 8000.
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
