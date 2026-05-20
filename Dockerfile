# syntax=docker/dockerfile:1.7
# ────────────────────────────────────────────────────────────────────
# NYC Transit Predictor — single image serving both the training
# pipeline and the Streamlit dashboard. Java 17 ships with the image
# (PySpark requirement); Python deps install in a single cached layer.
# ────────────────────────────────────────────────────────────────────
FROM python:3.11-slim-bookworm AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DEBIAN_FRONTEND=noninteractive

# ── System dependencies (Java for Spark, build tools, curl for healthcheck) ──
RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-17-jre-headless \
        procps \
        curl \
        ca-certificates \
        tini \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    PATH="/usr/lib/jvm/java-17-openjdk-amd64/bin:${PATH}" \
    PYSPARK_PYTHON=python3 \
    PYSPARK_DRIVER_PYTHON=python3

WORKDIR /app

# ── Python deps: copied first so they cache between code edits ──────
COPY requirements.txt requirements-dev.txt ./
RUN pip install --upgrade pip setuptools wheel \
 && pip install -r requirements.txt
# requirements-dev.txt is *not* installed in the image — it ships so that
# `docker compose run dashboard pip install -r requirements-dev.txt` works
# on demand for CI/dev workflows without bloating the production image.

# ── Application code ────────────────────────────────────────────────
COPY dashboard ./dashboard
COPY data ./data
COPY notebooks ./notebooks
COPY tests ./tests
COPY .streamlit ./.streamlit
COPY pyproject.toml ./
COPY .env.example ./.env.example

# ── Runtime defaults ────────────────────────────────────────────────
RUN mkdir -p /app/models /app/logs /app/dashboard/static/plots

EXPOSE 8501 4040 8888

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -fsS http://localhost:8501/_stcore/health || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["streamlit", "run", "dashboard/app.py", \
     "--server.address=0.0.0.0", \
     "--server.port=8501", \
     "--server.headless=true", \
     "--browser.gatherUsageStats=false"]
