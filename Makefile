# =============================================================================
# FastAPI DevOps Project Makefile
# =============================================================================
# Quick Start: make setup && make run
# =============================================================================

.PHONY: help setup install dev-install docker-build docker-run k8s-deploy k8s-delete test lint clean

# Default target
help:
	@echo "FastAPI DevOps Project"
	@echo "======================"
	@echo ""
	@echo "Setup:"
	@echo "  make setup        - Install all dependencies (Helm, kubectl check)"
	@echo "  make install      - Install Python production dependencies"
	@echo "  make dev-install  - Install Python dev dependencies (for testing)"
	@echo ""
	@echo "Docker:"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-run   - Run container locally"
	@echo "  make docker-stop  - Stop and remove container"
	@echo ""
	@echo "Kubernetes:"
	@echo "  make k8s-deploy   - Deploy to Kubernetes with Helm"
	@echo "  make k8s-status   - Check deployment status"
	@echo "  make k8s-logs     - View application logs"
	@echo "  make k8s-delete   - Remove from Kubernetes"
	@echo ""
	@echo "Development:"
	@echo "  make test         - Run tests with coverage"
	@echo "  make lint         - Run linter (Ruff)"
	@echo "  make clean        - Clean up generated files"

# -----------------------------------------------------------------------------
# Setup & Installation
# -----------------------------------------------------------------------------

setup: check-docker check-kubectl check-helm
	@echo "✅ All dependencies are installed!"
	@echo "Run 'make docker-build' to build the image"

check-docker:
	@which docker > /dev/null || (echo "❌ Docker not found. Install from https://docs.docker.com/get-docker/" && exit 1)
	@echo "✅ Docker installed"

check-kubectl:
	@which kubectl > /dev/null || (echo "❌ kubectl not found. Install from https://kubernetes.io/docs/tasks/tools/" && exit 1)
	@echo "✅ kubectl installed"

check-helm:
	@which helm > /dev/null || (echo "❌ Helm not found. Install with: brew install helm" && exit 1)
	@echo "✅ Helm installed"

install:
	pip install -r requirements.txt

dev-install: install
	pip install -r requirements-dev.txt

# -----------------------------------------------------------------------------
# Docker Commands
# -----------------------------------------------------------------------------

IMAGE_NAME ?= fastapi-app
IMAGE_TAG ?= latest

docker-build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
	@echo "✅ Built $(IMAGE_NAME):$(IMAGE_TAG)"

docker-run:
	docker run -d --name fastapi-app -p 8080:8080 \
		-e SECRET_KEY=dev-secret \
		$(IMAGE_NAME):$(IMAGE_TAG)
	@echo "✅ Running at http://localhost:8080"
	@echo "   Health: http://localhost:8080/health"

docker-stop:
	docker stop fastapi-app && docker rm fastapi-app
	@echo "✅ Container stopped and removed"

docker-logs:
	docker logs -f fastapi-app

# -----------------------------------------------------------------------------
# Kubernetes Commands
# -----------------------------------------------------------------------------

RELEASE_NAME ?= fastapi-app
CHART_PATH ?= ./helm/fastapi-app

k8s-deploy: docker-build
	helm upgrade --install $(RELEASE_NAME) $(CHART_PATH) \
		--set image.repository=$(IMAGE_NAME) \
		--set image.tag=$(IMAGE_TAG) \
		--set image.pullPolicy=Never
	@echo "✅ Deployed to Kubernetes"
	@echo "   Run 'make k8s-status' to check status"
	@echo "   Run 'kubectl port-forward svc/fastapi-app 8080:8080' to access"

k8s-status:
	@echo "=== Pods ==="
	kubectl get pods -l app.kubernetes.io/name=fastapi-app
	@echo ""
	@echo "=== Services ==="
	kubectl get svc -l app.kubernetes.io/name=fastapi-app

k8s-logs:
	kubectl logs -l app.kubernetes.io/name=fastapi-app -f

k8s-delete:
	helm uninstall $(RELEASE_NAME)
	@echo "✅ Removed from Kubernetes"

# -----------------------------------------------------------------------------
# Development Commands
# -----------------------------------------------------------------------------

test:
	pytest --cov=. --cov-report=term-missing tests/

lint:
	ruff check .
	ruff format --check .

lint-fix:
	ruff check --fix .
	ruff format .

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------

clean:
	rm -rf __pycache__ .pytest_cache .ruff_cache .coverage htmlcov
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@echo "✅ Cleaned up generated files"
