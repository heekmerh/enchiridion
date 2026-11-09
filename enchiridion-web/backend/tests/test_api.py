"""API smoke tests which never connect to production services."""

from fastapi.testclient import TestClient

from app.main import app


def test_root():
    with TestClient(app) as client:
        response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Enchiridion API is running"}


def test_readiness_requires_database_configuration(monkeypatch):
    monkeypatch.delenv("SUPABASE_DB_URL", raising=False)
    with TestClient(app) as client:
        response = client.get("/health/ready")
    assert response.status_code == 503
    assert "not configured" in response.json()["detail"]
