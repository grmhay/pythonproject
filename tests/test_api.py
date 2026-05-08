"""This module provides tests for the API module."""

# ruff: noqa: S101,PLR2004

from fastapi.testclient import TestClient

from zamazingo import __version__
from zamazingo.api import app


def test_read_root() -> None:
    """Test the root endpoint."""
    client = TestClient(app)
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": f"Hello from zamazingo v{__version__}!"}
