# Use slim and secure Python base image
FROM python:3.11-slim

# Unprivileged runtime user
RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

# Set working directory
WORKDIR /app

# Copy dependencies first (for caching)
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the app code
COPY --chown=app:app app/ ./app/

# Dev-mode SQLite file must live somewhere the unprivileged user can write
# (the default ../dev.db resolves to /dev.db). TEST/PROD use PostgreSQL.
ENV SQLITE_PATH=/app/data/dev.db
RUN mkdir -p /app/data && chown app:app /app/data

USER app

# Expose the port
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/', timeout=4).status == 200 else 1)"

# Start the app with uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
