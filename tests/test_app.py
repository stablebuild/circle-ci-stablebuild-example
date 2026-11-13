from app import app


def test_health():
    response = app.test_client().get("/health")
    assert response.json == {"status": "ok"}


def test_versions_lists_installed_packages():
    response = app.test_client().get("/versions")
    assert "flask" in {name.lower() for name in response.json}
