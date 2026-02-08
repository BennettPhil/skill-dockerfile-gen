#!/usr/bin/env bash
set -euo pipefail

LANG=""
VERSION="latest"
PORT="3000"
DOCKERIGNORE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lang) LANG="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --dockerignore) DOCKERIGNORE=true; shift ;;
    --validate)
      echo "Validating dockerfile-gen..."
      out=$("$0" --lang node 2>&1)
      if echo "$out" | grep -q "FROM node"; then
        echo "PASS: generates valid Node.js Dockerfile"
      else
        echo "FAIL: Node.js Dockerfile missing FROM"; exit 1
      fi
      out=$("$0" --lang python 2>&1)
      if echo "$out" | grep -q "FROM python"; then
        echo "PASS: generates valid Python Dockerfile"
      else
        echo "FAIL: Python Dockerfile missing FROM"; exit 1
      fi
      echo "PASS: all checks passed"
      exit 0
      ;;
    --help)
      echo "Usage: run.sh --lang LANGUAGE [OPTIONS]"
      echo ""
      echo "Generate optimized Dockerfiles."
      echo ""
      echo "Languages: node, python, go, rust, java"
      echo ""
      echo "Options:"
      echo "  --lang LANG       Target language (required)"
      echo "  --version VER     Base image version (default: latest)"
      echo "  --port PORT       Port to expose (default: 3000)"
      echo "  --dockerignore    Also output .dockerignore content"
      echo "  --validate        Run self-check"
      echo "  --help            Show this help"
      exit 0
      ;;
    -*) echo "ERROR: unknown option: $1" >&2; exit 2 ;;
    *) echo "ERROR: unexpected argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$LANG" ]]; then
  echo "ERROR: --lang is required" >&2
  exit 2
fi

node_version="$VERSION"
[[ "$node_version" == "latest" ]] && node_version="20"

case "$LANG" in
  node|nodejs)
    cat << DOCKERFILE
# ---- Build Stage ----
FROM node:${node_version}-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY . .
RUN npm run build --if-present

# ---- Production Stage ----
FROM node:${node_version}-alpine AS production
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -s /bin/sh -D appuser
WORKDIR /app
COPY --from=builder --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:appgroup /app .
USER appuser
EXPOSE ${PORT}
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT}/health || exit 1
CMD ["node", "index.js"]
DOCKERFILE
    ;;

  python)
    py_version="$VERSION"
    [[ "$py_version" == "latest" ]] && py_version="3.12"
    cat << DOCKERFILE
# ---- Build Stage ----
FROM python:${py_version}-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Production Stage ----
FROM python:${py_version}-slim AS production
RUN groupadd -r appgroup && useradd -r -g appgroup -s /sbin/nologin appuser
WORKDIR /app
COPY --from=builder /install /usr/local
COPY --chown=appuser:appgroup . .
USER appuser
EXPOSE ${PORT}
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:${PORT}/health')" || exit 1
CMD ["python", "app.py"]
DOCKERFILE
    ;;

  go|golang)
    go_version="$VERSION"
    [[ "$go_version" == "latest" ]] && go_version="1.22"
    cat << DOCKERFILE
# ---- Build Stage ----
FROM golang:${go_version}-alpine AS builder
RUN apk add --no-cache git
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/server .

# ---- Production Stage ----
FROM alpine:3.19 AS production
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -s /bin/sh -D appuser
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY --from=builder --chown=appuser:appgroup /app/server .
USER appuser
EXPOSE ${PORT}
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT}/health || exit 1
CMD ["./server"]
DOCKERFILE
    ;;

  rust)
    cat << DOCKERFILE
# ---- Build Stage ----
FROM rust:latest AS builder
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release && rm -rf src
COPY . .
RUN cargo build --release

# ---- Production Stage ----
FROM debian:bookworm-slim AS production
RUN groupadd -r appgroup && useradd -r -g appgroup -s /sbin/nologin appuser
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder --chown=appuser:appgroup /app/target/release/app .
USER appuser
EXPOSE ${PORT}
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD curl -f http://localhost:${PORT}/health || exit 1
CMD ["./app"]
DOCKERFILE
    ;;

  java)
    java_version="$VERSION"
    [[ "$java_version" == "latest" ]] && java_version="21"
    cat << DOCKERFILE
# ---- Build Stage ----
FROM eclipse-temurin:${java_version}-jdk-alpine AS builder
WORKDIR /app
COPY . .
RUN ./gradlew bootJar --no-daemon 2>/dev/null || mvn package -DskipTests 2>/dev/null || echo "Build tool not detected"

# ---- Production Stage ----
FROM eclipse-temurin:${java_version}-jre-alpine AS production
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -s /bin/sh -D appuser
WORKDIR /app
COPY --from=builder --chown=appuser:appgroup /app/build/libs/*.jar app.jar 2>/dev/null || \\
COPY --from=builder --chown=appuser:appgroup /app/target/*.jar app.jar
USER appuser
EXPOSE ${PORT}
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT}/actuator/health || exit 1
CMD ["java", "-jar", "app.jar"]
DOCKERFILE
    ;;

  *)
    echo "ERROR: unsupported language: $LANG" >&2
    echo "Supported: node, python, go, rust, java" >&2
    exit 1
    ;;
esac

# Dockerignore
if [[ "$DOCKERIGNORE" == true ]]; then
  echo ""
  echo "# --- .dockerignore ---"
  case "$LANG" in
    node|nodejs)
      cat << 'DI'
node_modules
npm-debug.log
.git
.gitignore
.env
.env.*
Dockerfile
docker-compose*
.dockerignore
README.md
.vscode
.idea
coverage
.nyc_output
DI
      ;;
    python)
      cat << 'DI'
__pycache__
*.pyc
*.pyo
.git
.gitignore
.env
.env.*
Dockerfile
docker-compose*
.dockerignore
venv
.venv
.pytest_cache
.mypy_cache
DI
      ;;
    go|golang)
      cat << 'DI'
.git
.gitignore
.env
Dockerfile
docker-compose*
.dockerignore
vendor
*.test
README.md
DI
      ;;
    *)
      cat << 'DI'
.git
.gitignore
.env
Dockerfile
docker-compose*
.dockerignore
README.md
DI
      ;;
  esac
fi

echo "OK: generated Dockerfile for $LANG" >&2
