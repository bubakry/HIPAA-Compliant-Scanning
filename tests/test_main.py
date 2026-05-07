from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_root_returns_service_metadata():
    response = client.get("/")

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "ok"
    assert payload["compliance_profile"] == "HIPAA"


def test_liveness_probe():
    response = client.get("/health/live")

    assert response.status_code == 200
    assert response.json() == {"status": "alive"}


def test_readiness_probe():
    response = client.get("/health/ready")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["checks"]["logging"] == "configured"


def test_request_id_is_echoed_when_supplied():
    supplied = "req-1234-abcd"
    response = client.get("/health/live", headers={"x-request-id": supplied})

    assert response.status_code == 200
    assert response.headers["x-request-id"] == supplied


def test_request_id_is_generated_when_missing():
    response = client.get("/health/live")

    assert response.status_code == 200
    request_id = response.headers.get("x-request-id")
    assert request_id
    assert len(request_id) >= 16


def test_docs_endpoints_are_disabled():
    for path in ("/docs", "/redoc"):
        assert client.get(path).status_code == 404


def test_unknown_path_returns_404():
    response = client.get("/this-path-does-not-exist")
    assert response.status_code == 404
