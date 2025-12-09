# Helm Chart Documentation

> Detailed guide to the FastAPI Helm chart: architecture, deployment, and design decisions.

## Table of Contents

- [Overview](#overview)
- [Chart Structure](#chart-structure)
- [How Deployment Works](#how-deployment-works)
- [Resource Breakdown](#resource-breakdown)
- [Configuration Guide](#configuration-guide)
- [Design Decisions](#design-decisions)
- [Deployment Commands](#deployment-commands)
- [Troubleshooting](#troubleshooting)

---

## Overview

### What is Helm?

Helm is the **package manager for Kubernetes**. It bundles all Kubernetes resources (Deployments, Services, ConfigMaps, etc.) into a single deployable unit called a **chart**.

### Why Use Helm?

| Benefit | Description |
|---------|-------------|
| **Templating** | Reusable manifests with variable substitution |
| **Versioning** | Track releases, rollback to previous versions |
| **Configuration** | Override values without modifying templates |
| **Reproducibility** | Same chart deploys identically across environments |

### Target Environment

> **Note**: This Helm chart is configured for **Docker Desktop Kubernetes**. Docker Desktop provides a single-node Kubernetes cluster that's perfect for local development and testing.

To enable Kubernetes in Docker Desktop:
1. Open Docker Desktop → Settings → Kubernetes
2. Check "Enable Kubernetes"
3. Click "Apply & Restart"

Verify your cluster:
```bash
kubectl config current-context    # Should show: docker-desktop
kubectl cluster-info              # Should show control plane running
```

---

## Chart Structure

```
helm/fastapi-app/
├── Chart.yaml              # Chart metadata (name, version)
├── values.yaml             # Default configuration values
└── templates/
    ├── _helpers.tpl        # Template helper functions
    ├── deployment.yaml     # Pod specification
    ├── service.yaml        # Network exposure
    ├── ingress.yaml        # External access (optional)
    ├── configmap.yaml      # Non-sensitive configuration
    ├── secret.yaml         # Sensitive configuration
    └── hpa.yaml            # Horizontal Pod Autoscaler (optional)
```

### File Purposes

| File | Purpose |
|------|---------|
| `Chart.yaml` | Defines chart name, version, and metadata |
| `values.yaml` | Default values that can be overridden at install |
| `_helpers.tpl` | Reusable template functions (naming, labels) |
| `deployment.yaml` | Creates pods with containers, probes, resources |
| `service.yaml` | Exposes pods internally within the cluster |
| `ingress.yaml` | Routes external traffic to the service |
| `configmap.yaml` | Stores non-sensitive environment variables |
| `secret.yaml` | Stores sensitive data (passwords, keys) |
| `hpa.yaml` | Auto-scales pods based on CPU usage |

---

## How Deployment Works

### Deployment Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                      helm install fastapi-app                        │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│  1. Helm reads Chart.yaml and values.yaml                          │
│  2. Renders templates with values substituted                       │
│  3. Sends rendered YAML to Kubernetes API                          │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│               Kubernetes Creates Resources                          │
├─────────────────────────────────────────────────────────────────────┤
│  ConfigMap ──► Secret ──► Deployment ──► Service ──► Ingress       │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Deployment creates ReplicaSet → ReplicaSet creates Pod(s)         │
│  Pod starts container, passes health checks, becomes Ready         │
│  Service routes traffic to Ready pods                               │
└─────────────────────────────────────────────────────────────────────┘
```

### What Happens During Install

1. **ConfigMap Created** - Environment variables (APP_NAME, APP_ENV, APP_VERSION)
2. **Secret Created** - Sensitive data (SECRET_KEY)
3. **Deployment Created** - Pod specification with:
   - Container image reference
   - Environment variables from ConfigMap/Secret
   - Resource requests/limits
   - Liveness/readiness probes
4. **ReplicaSet Created** - Manages desired number of pod replicas
5. **Pod(s) Created** - Actual containers running your application
6. **Service Created** - Stable network endpoint for pods
7. **Ingress Created** (if enabled) - External access routing

---

## Resource Breakdown

### Deployment (deployment.yaml)

The Deployment is the core resource that manages your application pods.

```yaml
# Key sections explained:

spec:
  replicas: 1                    # Number of pod instances
  strategy:
    type: RollingUpdate          # Zero-downtime deployments
    rollingUpdate:
      maxSurge: 1                # Create 1 new pod before terminating old
      maxUnavailable: 0          # Never have fewer than desired replicas

  template:
    metadata:
      annotations:
        checksum/config: {{ sha256sum }}  # Triggers restart on config change
    
    spec:
      securityContext:
        runAsNonRoot: true       # Security: no root access
        runAsUser: 1000          # Run as user 1000 (appuser)
      
      containers:
        - name: fastapi-app
          image: ghcr.io/rupertbothma/devtest:latest
          
          envFrom:
            - configMapRef: ...   # Load all ConfigMap keys as env vars
            - secretRef: ...      # Load all Secret keys as env vars
          
          resources:
            requests:             # Minimum guaranteed resources
              cpu: 100m           # 0.1 CPU cores
              memory: 128Mi       # 128 MB RAM
            limits:               # Maximum allowed resources
              cpu: 500m           # 0.5 CPU cores
              memory: 256Mi       # 256 MB RAM
          
          livenessProbe:          # Is the container healthy?
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
          
          readinessProbe:         # Is the container ready for traffic?
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
```

#### Why These Choices?

| Setting | Value | Reason |
|---------|-------|--------|
| `replicas: 1` | Single instance | Local development; increase for production |
| `RollingUpdate` | Zero-downtime | No service interruption during updates |
| `maxUnavailable: 0` | Never fewer pods | Ensures availability during updates |
| `runAsNonRoot: true` | Security | Prevents container escape attacks |
| `resources.requests` | 100m CPU, 128Mi | Scheduler guarantees these resources |
| `resources.limits` | 500m CPU, 256Mi | Prevents runaway resource consumption |
| `livenessProbe` | /health | Restarts container if unhealthy |
| `readinessProbe` | /health | Removes from service if not ready |

### Service (service.yaml)

```yaml
spec:
  type: ClusterIP              # Internal cluster access only
  ports:
    - port: 8080               # Service port
      targetPort: http         # Container port (named)
  selector:
    app.kubernetes.io/name: fastapi-app  # Routes to matching pods
```

#### Service Types Explained

| Type | Use Case | Our Choice |
|------|----------|------------|
| `ClusterIP` | Internal access only | ✅ Default, secure |
| `NodePort` | Expose on each node's IP | Development |
| `LoadBalancer` | Cloud load balancer | Production (cloud) |

### Ingress (ingress.yaml)

Only created when `ingress.enabled: true`.

```yaml
spec:
  ingressClassName: nginx        # Uses nginx ingress controller
  rules:
    - host: fastapi.local        # Domain name
      http:
        paths:
          - path: /              # All paths
            backend:
              service:
                name: fastapi-app
                port: 8080
```

#### Why nginx-ingress?

| Reason | Description |
|--------|-------------|
| Standard | Most common ingress controller |
| Docker Desktop | Works out-of-box with Docker Desktop |
| Features | SSL termination, rate limiting, etc. |

### ConfigMap & Secret

```yaml
# ConfigMap - Non-sensitive data
data:
  APP_NAME: "awesome-api"
  APP_ENV: "production"
  APP_VERSION: "0.1.0"

# Secret - Sensitive data  
stringData:
  SECRET_KEY: "change-me-in-production"
```

#### Why Separate ConfigMap and Secret?

| Aspect | ConfigMap | Secret |
|--------|-----------|--------|
| **Security** | Plain text | Base64 encoded (can be encrypted at rest) |
| **Access Control** | Standard RBAC | Stricter RBAC possible |
| **Use Case** | App settings, feature flags | Passwords, API keys, tokens |
| **Best Practice** | Commit to Git | **Never** commit to Git |

### HorizontalPodAutoscaler (hpa.yaml)

Only created when `autoscaling.enabled: true`.

```yaml
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: fastapi-app
  minReplicas: 1
  maxReplicas: 3
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80    # Scale when CPU > 80%
```

---

## Configuration Guide

### Override Values

```bash
# Via --set flag
helm install fastapi-app ./helm/fastapi-app \
  --set replicaCount=3 \
  --set image.tag=v1.2.0

# Via values file
helm install fastapi-app ./helm/fastapi-app \
  -f my-values.yaml
```

### Common Overrides

| Override | Example | Purpose |
|----------|---------|---------|
| `replicaCount` | `3` | Run multiple instances |
| `image.tag` | `v1.2.0` | Deploy specific version |
| `image.repository` | `my-registry/app` | Use different registry |
| `resources.limits.memory` | `512Mi` | Increase memory limit |
| `ingress.enabled` | `true` | Enable external access |
| `autoscaling.enabled` | `true` | Enable auto-scaling |
| `config.APP_ENV` | `staging` | Change environment |
| `secrets.SECRET_KEY` | `prod-key` | Set production secret |

### Environment-Specific Values Files

```bash
# Create environment-specific values
cat > values-production.yaml << EOF
replicaCount: 3
image:
  tag: "v1.0.0"
resources:
  limits:
    cpu: 1000m
    memory: 512Mi
autoscaling:
  enabled: true
  maxReplicas: 10
config:
  APP_ENV: "production"
EOF

# Deploy with environment values
helm install fastapi-app ./helm/fastapi-app -f values-production.yaml
```

---

## Design Decisions

### 1. ClusterIP Service (not LoadBalancer)

**Decision**: Use `ClusterIP` as default service type.

**Rationale**:
- More secure (not directly exposed)
- Works with all Kubernetes distributions
- Use Ingress for external access (more control)
- LoadBalancer creates cloud resources (cost)

### 2. Separate ConfigMap and Secret

**Decision**: Split configuration into ConfigMap and Secret.

**Rationale**:
- Security: Secrets can have stricter access controls
- Auditability: Secret access can be logged
- Best practice: Never store secrets in ConfigMaps

### 3. Health Check on /health Endpoint

**Decision**: Use existing `/health` endpoint for probes.

**Rationale**:
- Already implemented in the application
- Lightweight check (no database calls)
- Separate from `/config` which exposes data

### 4. Resource Requests and Limits

**Decision**: Set conservative defaults (100m/128Mi request, 500m/256Mi limit).

**Rationale**:
- Requests ensure QoS and scheduling
- Limits prevent noisy neighbor issues
- FastAPI is lightweight, doesn't need much
- Can be overridden for production

### 5. Rolling Update Strategy

**Decision**: `maxSurge: 1, maxUnavailable: 0`

**Rationale**:
- Zero-downtime deployments
- Always maintain capacity
- New pod must be ready before old terminates

### 6. Non-root Security Context

**Decision**: `runAsNonRoot: true, runAsUser: 1000`

**Rationale**:
- Matches Dockerfile (runs as `appuser` UID 1000)
- Security best practice
- Prevents privilege escalation attacks

### 7. Checksum Annotations

**Decision**: Include ConfigMap/Secret checksums in pod annotations.

**Rationale**:
- Triggers pod restart when config changes
- Without this, pods don't restart on ConfigMap updates
- Ensures pods always have latest configuration

---

## Deployment Commands

### Basic Operations

```bash
# Install
helm install fastapi-app ./helm/fastapi-app

# Install with custom values
helm install fastapi-app ./helm/fastapi-app \
  --set secrets.SECRET_KEY=my-production-key

# List releases
helm list

# Check release status
helm status fastapi-app

# Upgrade (apply changes)
helm upgrade fastapi-app ./helm/fastapi-app

# Rollback to previous revision
helm rollback fastapi-app 1

# Uninstall
helm uninstall fastapi-app
```

### Debugging

```bash
# Preview rendered templates
helm template fastapi-app ./helm/fastapi-app

# Validate chart syntax
helm lint ./helm/fastapi-app

# Dry run (show what would be created)
helm install fastapi-app ./helm/fastapi-app --dry-run

# Get deployed manifest
helm get manifest fastapi-app
```

### Testing Deployed Application

```bash
# Port forward to access locally
kubectl port-forward svc/fastapi-app 8080:8080

# In another terminal
curl http://localhost:8080/health
curl http://localhost:8080/config
curl http://localhost:8080/version
```

---

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=fastapi-app

# Describe pod for events
kubectl describe pod <pod-name>

# Check logs
kubectl logs -l app.kubernetes.io/name=fastapi-app
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `ImagePullBackOff` | Can't pull image | Check image name, registry auth |
| `CrashLoopBackOff` | Container keeps crashing | Check logs for error |
| `Pending` | No suitable node | Check resources, node capacity |
| `CreateContainerConfigError` | Bad config | Check ConfigMap/Secret names |

### Image Pull Issues (Local Development)

When using locally built images:

```bash
# Build with Docker Desktop's daemon
docker build -t fastapi-app:test .

# Install with local image
helm install fastapi-app ./helm/fastapi-app \
  --set image.repository=fastapi-app \
  --set image.tag=test \
  --set image.pullPolicy=Never
```

---
