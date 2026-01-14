# tests/test_basic.py
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_endpoint():
    """Test health endpoint returns 200"""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

def test_metrics_endpoint():
    """Test metrics endpoint returns 200"""
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "text/plain" in response.headers["content-type"]

def test_root_endpoint():
    """Test root endpoint returns API info"""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "service" in data
    assert "version" in data

def test_security_headers():
    """Test security headers are present"""
    response = client.get("/")
    headers = response.headers
    
    # Check tracing headers
    assert "x-request-id" in headers
    
    # Check security headers
    assert "x-content-type-options" in headers
    assert headers["x-content-type-options"] == "nosniff"

if __name__ == "__main__":
    pytest.main([__file__, "-v"])