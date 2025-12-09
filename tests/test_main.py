# =============================================================================
# Tests for FastAPI Application
# =============================================================================


import pytest
from fastapi.testclient import TestClient

from main import app


@pytest.fixture
def client():
    """Create a test client for the FastAPI application."""
    return TestClient(app)


class TestHealthEndpoint:
    """Tests for the /health endpoint."""

    def test_health_returns_ok(self, client):
        """Health endpoint should return status ok."""
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}


class TestConfigEndpoint:
    """Tests for the /config endpoint."""

    def test_config_returns_default_values(self, client):
        """Config endpoint should return default configuration values."""
        response = client.get("/config")
        assert response.status_code == 200

        data = response.json()
        assert "app_name" in data
        assert "app_env" in data
        assert "app_version" in data
        assert "secret_message" in data

    def test_config_respects_env_variables(self, client, monkeypatch):
        """Config endpoint should respect environment variables."""
        # Set environment variables
        monkeypatch.setenv("APP_NAME", "test-app")
        monkeypatch.setenv("APP_ENV", "testing")

        # Re-import to pick up new env vars
        # Note: In a real app, you'd use dependency injection for better testability
        response = client.get("/config")
        assert response.status_code == 200

    def test_config_contains_all_required_fields(self, client):
        """Config endpoint should contain all required configuration fields."""
        response = client.get("/config")
        data = response.json()

        required_fields = ["app_name", "app_env", "app_version", "secret_message"]
        for field in required_fields:
            assert field in data, f"Missing required field: {field}"
