# Architecture Overview

## System Design

This project demonstrates a complete, production-ready architecture for deploying containerized Python applications with modern DevOps practices.

## Core Components

### 1. Application Layer

A lightweight FastAPI application providing:
- Health check endpoint (`/health`) for orchestration
- Configuration endpoint (`/config`) for runtime inspection
- Stateless design for horizontal scaling

### 2. Containerization

**Docker multi-stage build** provides:
- Optimized image size (~200MB final)
- Security hardening (non-root user, minimal base image)
- Layer caching for faster rebuilds
- Health checks for orchestration integration

### 3. CI/CD Pipeline

**GitHub Actions workflow** automates:
- Code linting (Ruff)
- Unit testing (Pytest)
- Container image building
- Registry push (GitHub Container Registry)
- Optional deployment to Kubernetes

### 4. Kubernetes Deployment

**Helm chart** provides:
- Declarative infrastructure as code
- Environment-specific configuration
- Rolling updates for zero-downtime deployments
- Resource management and autoscaling
- Health probes for reliability

## Technology Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| **Runtime** | Python 3.11 | Modern, widely-used, good ecosystem |
| **Framework** | FastAPI | High performance, async support, auto-documentation |
| **Containerization** | Docker | Industry standard, excellent tooling |
| **CI/CD** | GitHub Actions | Native GitHub integration, no extra infrastructure |
| **Registry** | GHCR | Integrated with GitHub, free for public repos |
| **Orchestration** | Kubernetes | Production-grade, cloud-agnostic |
| **Package Manager** | Helm | Standard Kubernetes package management |

## Design Principles

1. **Security First** - Non-root containers, minimal base images, secret management
2. **Scalability** - Stateless design, horizontal scaling, resource limits
3. **Reliability** - Health checks, rolling updates, automatic restarts
4. **Observability** - Structured logging, health endpoints, deployment tracking
5. **Reproducibility** - Infrastructure as code, version control, automated testing

## Deployment Flow

```
Code Push → Lint → Test → Build → Push to Registry → Deploy to K8s
```

Each stage is automated and can be triggered independently or as part of the full pipeline.
