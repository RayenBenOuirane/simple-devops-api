# Dockerfile - DevOps API Container
# Multi-stage build for optimized image

# Stage 1: Builder
FROM python:3.11-slim AS builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim

WORKDIR /app

# Create non-root user for security
RUN groupadd -r api && useradd -r -g api -u 1000 api

# Copy Python dependencies from builder
COPY --from=builder /root/.local /home/api/.local
ENV PATH=/home/api/.local/bin:$PATH

# Copy application code
COPY app/ ./app/

# Set proper permissions
RUN chown -R api:api /app

# Switch to non-root user
USER api

# Expose application port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]