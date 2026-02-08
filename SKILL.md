---
name: dockerfile-gen
description: Generate optimized, multi-stage Dockerfiles for common languages and frameworks with best practices built in.
version: 0.1.0
license: Apache-2.0
---

# dockerfile-gen

Generates production-ready, multi-stage Dockerfiles for common languages and frameworks.

## Purpose

Writing good Dockerfiles is hard — layer caching, multi-stage builds, non-root users, health checks. This skill generates optimized Dockerfiles following best practices for your language/framework.

## Contract

- Accepts a language/framework via `--lang` flag
- Outputs a complete Dockerfile to stdout
- Multi-stage builds by default (build + runtime stages)
- Non-root user in production stage
- Health check included
- Proper `.dockerignore` suggestions via `--dockerignore`
- Exit 0 on success (last line: `OK: generated Dockerfile for <lang>`)
- Exit 1 if unsupported language
- Exit 2 on invalid usage

## Usage

```bash
# Generate a Node.js Dockerfile
./scripts/run.sh --lang node
# OK: generated Dockerfile for node

# Generate with specific Node version
./scripts/run.sh --lang node --version 20

# Generate Python Dockerfile
./scripts/run.sh --lang python

# Generate Go Dockerfile
./scripts/run.sh --lang go

# Also generate .dockerignore
./scripts/run.sh --lang node --dockerignore
```

## Arguments and Options

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| --lang | Yes | - | Language: node, python, go, rust, java |
| --version | No | latest | Base image version |
| --port | No | 3000 | Port to expose |
| --dockerignore | No | false | Also output a .dockerignore |
| --validate | No | - | Run self-check |
| --help | No | - | Show usage |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Unsupported language |
| 2 | Invalid input / usage error |

## Validation

Run `./scripts/run.sh --validate` to verify the skill generates valid Dockerfiles.
