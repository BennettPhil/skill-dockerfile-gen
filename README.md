# dockerfile-gen

Generate optimized, multi-stage Dockerfiles for common languages and frameworks.

## Quick Start

```bash
./scripts/run.sh --lang node
```

## Prerequisites

- Bash 4+

## Usage

```bash
# Node.js with specific version
./scripts/run.sh --lang node --version 20 --port 8080

# Python
./scripts/run.sh --lang python

# Go with .dockerignore
./scripts/run.sh --lang go --dockerignore

# Rust
./scripts/run.sh --lang rust
```

See [SKILL.md](SKILL.md) for full contract.
