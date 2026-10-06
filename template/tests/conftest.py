"""Shared pytest fixtures."""

import pytest


@pytest.fixture
def anyio_backend() -> str:
    """Pin anyio's backend to asyncio.

    Without this, anyio's pytest plugin parametrises every `@pytest.mark.anyio`
    test over each installed backend. The code under test is asyncio-only --
    fastmcp's Client calls asyncio.create_task directly -- so a trio run fails
    with "no running event loop" no matter what is installed.
    """
    return "asyncio"
