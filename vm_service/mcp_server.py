"""This module provides the MCP server."""

from fastmcp import FastMCP

from zamazingo import __version__

mcp = FastMCP("zamazingo")


@mcp.tool
def get_version() -> str:
    """Return the current package version."""
    return __version__


@mcp.resource("info://version")
def version_resource() -> str:
    """Return the package version as a resource."""
    return __version__


def run() -> None:
    """Run the MCP server."""
    mcp.run()
