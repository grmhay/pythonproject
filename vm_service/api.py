"""This module provides the FastAPI application."""

import uvicorn
from fastapi import FastAPI

from vm_service import __version__

app = FastAPI(title="vm-service", version=__version__)


@app.get("/")
def read_root() -> dict[str, str]:
    """Return a welcome message."""
    return {"message": f"Hello from vm_service v{__version__}!"}


def run() -> None:
    """Run the API server."""
    uvicorn.run("vm_service.api:app", host="0.0.0.0", port=8000, reload=False)  # noqa: S104
