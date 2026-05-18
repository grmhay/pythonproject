"""Tests for lifecycle operations."""

import pytest

from vm_service import operations


def test_create_raises_not_implemented() -> None:
    """Test that create raises NotImplementedError until implemented."""
    with pytest.raises(NotImplementedError):
        operations.create(100)


def test_start_raises_not_implemented() -> None:
    """Test that start raises NotImplementedError until implemented."""
    with pytest.raises(NotImplementedError):
        operations.start(100)


def test_stop_raises_not_implemented() -> None:
    """Test that stop raises NotImplementedError until implemented."""
    with pytest.raises(NotImplementedError):
        operations.stop(100)


def test_destroy_raises_not_implemented() -> None:
    """Test that destroy raises NotImplementedError until implemented."""
    with pytest.raises(NotImplementedError):
        operations.destroy(100)


def test_resize_raises_not_implemented() -> None:
    """Test that resize raises NotImplementedError until implemented."""
    with pytest.raises(NotImplementedError):
        operations.resize(100, vcpus=4, memory=8192)
