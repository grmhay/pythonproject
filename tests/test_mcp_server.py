"""This module provides tests for the MCP server module."""

# ruff: noqa: S101

import pytest
from fastmcp import Client

from zamazingo import __version__
from zamazingo.mcp_server import mcp


@pytest.mark.anyio
async def test_get_version_tool() -> None:
    """Test that the get_version tool returns the package version."""
    async with Client(mcp) as client:
        result = await client.call_tool("get_version", {})
        assert result.data == __version__


@pytest.mark.anyio
async def test_version_resource() -> None:
    """Test that the version resource contains the package version."""
    async with Client(mcp) as client:
        content = await client.read_resource("info://version")
        assert __version__ in content[0].text
