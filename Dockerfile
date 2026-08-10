# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (multi-stage, bảo mật, nhẹ)
# ═══════════════════════════════════════════════════════════════════

# Stage 1: builder — cài dependency (nặng, có compiler, bị bỏ đi sau khi build)
FROM python:3.11-slim AS builder

WORKDIR /install

COPY requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# Stage 2: runtime — chỉ copy kết quả cài đặt, không có compiler
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy kết quả cài đặt từ stage builder
COPY --from=builder /install /usr/local

# Copy source code SAU khi đã cài dependency (tận dụng Docker cache)
COPY app ./app
COPY utils ./utils
COPY requirements.txt .

# Tạo user thường — không chạy container bằng root
RUN useradd --create-home --uid 10001 appuser
USER appuser

# Expose cổng — cloud tự gán cổng thật qua biến môi trường PORT
EXPOSE 8000

# Healthcheck — orchestrator dùng để biết container còn sống không
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health').read()" || exit 1

# Đọc cổng từ biến môi trường, mặc định 8000
CMD ["sh", "-c", "python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
