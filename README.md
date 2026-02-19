# FastAPI Production Template

[![CI/CD Pipeline](https://github.com/RupertBothma/devtest/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/RupertBothma/devtest/actions/workflows/ci-cd.yml)

A production-ready FastAPI template with Docker containerization, automated CI/CD pipeline, and Kubernetes deployment via Helm. This project demonstrates best practices for containerizing, testing, and deploying Python applications at scale.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Docker Containerization](#docker-containerization)
- [CI/CD Pipeline](#cicd-pipeline)
- [Kubernetes & Helm](#kubernetes--helm)
- [Configuration Reference](#configuration-reference)
- [Technical Decisions](#technical-decisions)
- [Troubleshooting](#troubleshooting)

---

## Overview

This repository provides a complete, production-ready template for deploying Python FastAPI applications:

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Container** | Docker (multi-stage) | Optimized, secure containerization |
| **CI/CD** | GitHub Actions | Automated lint, test, build, push |
| **Registry** | GitHub Container Registry | Container image storage |
| **Orchestration** | Kubernetes + Helm | Production-grade deployment |

### Application Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check (returns `{"status": "ok"}`) |
| `/config` | GET | Returns current configuration |

---

## Prerequisites

| Tool | Version | Installation |
|------|---------|--------------|
| Docker | 20.10+ | [docs.docker.com](https://docs.docker.com/get-docker/) |
| kubectl | 1.25+ | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| Helm | 3.10+ | [helm.sh](https://helm.sh/docs/intro/install/) |
| Docker Desktop | Latest | Enable Kubernetes in Settings |

> **Note**: This project uses **Docker Desktop Kubernetes** as the target environment. Docker Desktop provides a local single-node Kubernetes cluster ideal for development and testing. To enable: Docker Desktop → Settings → Kubernetes → Enable Kubernetes.

---

## Quick Start

### Using Makefile (Recommended)

```bash
# Clone repository
git clone https://github.com/RupertBothma/devtest.git
cd devtest

# Check all dependencies are installed
make setup

# Build and run with Docker
make docker-build
make docker-run

# Or deploy to Kubernetes
make k8s-deploy

# Test
curl http://localhost:8080/health
```

Run `make help` to see all available commands.

### Manual Commands

```bash
# Option 1: Run with Docker
docker build -t fastapi-app .
docker run -p 8080:8080 -e SECRET_KEY=my-secret fastapi-app

# Option 2: Deploy to Kubernetes
helm install fastapi-app ./helm/fastapi-app
kubectl port-forward svc/fastapi-app 8080:8080

# Test
curl http://localhost:8080/health
```

---

## Docker Containerization

### Build & Run

```bash
# Build image
docker build -t fastapi-app:latest .

# Run container
docker run -d --name fastapi \
  -p 8080:8080 \
  -e SECRET_KEY=your-secret-key \
  fastapi-app:latest

# Verify
curl http://localhost:8080/health
docker exec fastapi whoami  # Should output: appuser
```

### Dockerfile Features

| Feature | Implementation | Justification |
|---------|----------------|---------------|
| Multi-stage build | Builder + Runtime stages | Reduces image size, excludes build tools |
| Base image | `python:3.11-slim` | Balance of size (~150MB base) and compatibility |
| Non-root user | `appuser` (UID 1000) | Security best practice, prevents privilege escalation |
| Layer caching | COPY requirements.txt first | Faster rebuilds when only code changes |
| Health check | Built-in HEALTHCHECK | Container orchestration support |

---

## CI/CD Pipeline

### Pipeline Stages

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  Lint   │───▶│  Test   │───▶│  Build  │───▶│  Push   │
│ (Ruff)  │    │(Pytest) │    │(Docker) │    │ (GHCR)  │
└─────────┘    └─────────┘    └─────────┘    └─────────┘
```

### Workflow Triggers

| Event | Branches | Actions |
|-------|----------|---------|
| Push | main, master | Lint → Test → Build → Push |
| Pull Request | main, master | Lint → Test → Build (no push) |

### Local Testing

```bash
# Install dev dependencies
pip install -r requirements-dev.txt

# Run linter
ruff check .
ruff format --check .

# Run tests
pytest --cov=. tests/
```

---

## Kubernetes & Helm

### Installation

```bash
# Basic install
helm install fastapi-app ./helm/fastapi-app

# Install with custom values
helm install fastapi-app ./helm/fastapi-app \
  --set secrets.SECRET_KEY=production-secret \
  --set config.APP_ENV=production

# Upgrade
helm upgrade fastapi-app ./helm/fastapi-app

# Rollback
helm rollback fastapi-app 1

# Uninstall
helm uninstall fastapi-app
```

### Chart Resources

| Resource | File | Description |
|----------|------|-------------|
| Deployment | `deployment.yaml` | Pod spec with probes, resources |
| Service | `service.yaml` | ClusterIP service on port 8080 |
| Ingress | `ingress.yaml` | Optional external access |
| ConfigMap | `configmap.yaml` | Non-sensitive config |
| Secret | `secret.yaml` | Sensitive config (SECRET_KEY) |
| HPA | `hpa.yaml` | Optional autoscaling |

### Enable Ingress (Docker Desktop)

```bash
# Install nginx-ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Enable ingress in Helm
helm upgrade fastapi-app ./helm/fastapi-app --set ingress.enabled=true

# Add to /etc/hosts
echo "127.0.0.1 fastapi.local" | sudo tee -a /etc/hosts

# Access
curl http://fastapi.local/health
```

---

## Configuration Reference

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_NAME` | awesome-api | Application name |
| `APP_ENV` | development | Environment (development/staging/production) |
| `APP_VERSION` | 0.1.0 | Application version |
| `SECRET_KEY` | secureme | **Sensitive** - Change in production! |
| `PORT` | 8080 | Server port |

### Helm Values

```yaml
# Override examples
replicaCount: 3
image:
  repository: ghcr.io/your-org/your-app
  tag: "v1.0.0"
resources:
  limits:
    cpu: 1000m
    memory: 512Mi
autoscaling:
  enabled: true
  maxReplicas: 5
```

---

## Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Base Image** | `python:3.11-slim` | Debian-based for reliability; slim variant reduces size; 3.11 for performance |
| **Linter** | Ruff | 10-100x faster than flake8; combines linting + formatting; actively maintained |
| **Registry** | GHCR | Integrated with GitHub Actions; uses GITHUB_TOKEN; no extra credentials |
| **Secrets** | K8s Secrets | Simple, built-in solution; production deployments should use External Secrets or Sealed Secrets |
| **Probes** | HTTP /health | Native endpoint; appropriate for stateless API |
| **Update Strategy** | RollingUpdate | Zero-downtime deployments; maxSurge=1, maxUnavailable=0 |

---

## Troubleshooting

### Docker Issues

```bash
# Container won't start
docker logs <container-id>

# Permission denied
# Ensure Dockerfile has: USER appuser
docker exec <container> whoami

# Port already in use
docker ps  # Find conflicting container
docker stop <container-id>
```

### Kubernetes Issues

```bash
# Pod not starting
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# ImagePullBackOff
# Check image exists and is accessible
docker pull ghcr.io/rupertbothma/devtest:latest

# Helm install fails
helm lint ./helm/fastapi-app
helm template ./helm/fastapi-app  # Preview rendered templates
```

### CI/CD Issues

```bash
# View workflow logs
# Go to: GitHub → Actions → Select workflow run

# Test locally with act (optional)
brew install act
act -j lint
```

---

## Cleanup

```bash
# Docker
docker stop fastapi && docker rm fastapi
docker rmi fastapi-app:latest

# Kubernetes
helm uninstall fastapi-app

# All Docker resources
docker system prune -a
```

---

## License

MIT License - See [LICENSE](LICENSE) for details.
