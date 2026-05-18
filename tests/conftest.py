"""Pytest configuration and shared fixtures."""

import pytest


@pytest.fixture
def anyio_backend() -> str:
    """Restrict anyio tests to asyncio; trio is not available in this environment."""
    return "asyncio"
