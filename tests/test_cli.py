"""Tests for CLI commands."""

# ruff: noqa: S101

from unittest.mock import patch

from click.testing import CliRunner

from vm_service.cli import main


def test_create_delegates_to_operations() -> None:
    """Test that the create command delegates to operations.create."""
    runner = CliRunner()
    with patch("vm_service.cli.operations.create") as mock_create:
        result = runner.invoke(main, ["create", "100"])
        assert result.exit_code == 0
        mock_create.assert_called_once_with(100, node=None, template=None)
        assert "VM 100 created" in result.output


def test_create_with_options() -> None:
    """Test that the create command passes node and template options."""
    runner = CliRunner()
    with patch("vm_service.cli.operations.create") as mock_create:
        result = runner.invoke(
            main, ["create", "101", "--node", "pve1", "--template", "ubuntu-22"]
        )
        assert result.exit_code == 0
        mock_create.assert_called_once_with(101, node="pve1", template="ubuntu-22")


def test_start_delegates_to_operations() -> None:
    """Test that the start command delegates to operations.start."""
    runner = CliRunner()
    with patch("vm_service.cli.operations.start") as mock_start:
        result = runner.invoke(main, ["start", "100"])
        assert result.exit_code == 0
        mock_start.assert_called_once_with(100)
        assert "VM 100 started" in result.output


def test_stop_delegates_to_operations() -> None:
    """Test that the stop command delegates to operations.stop."""
    runner = CliRunner()
    with patch("vm_service.cli.operations.stop") as mock_stop:
        result = runner.invoke(main, ["stop", "100"])
        assert result.exit_code == 0
        mock_stop.assert_called_once_with(100)
        assert "VM 100 stopped" in result.output


def test_destroy_delegates_to_operations() -> None:
    """Test that the destroy command delegates to operations.destroy."""
    runner = CliRunner()
    with patch("vm_service.cli.operations.destroy") as mock_destroy:
        result = runner.invoke(main, ["destroy", "100"])
        assert result.exit_code == 0
        mock_destroy.assert_called_once_with(100)
        assert "VM 100 destroyed" in result.output


def test_resize_delegates_to_operations() -> None:
    """Test that the resize command delegates to operations.resize."""
    runner = CliRunner()
    with patch("vm_service.cli.operations.resize") as mock_resize:
        result = runner.invoke(
            main, ["resize", "100", "--vcpus", "4", "--memory", "8192"]
        )
        assert result.exit_code == 0
        mock_resize.assert_called_once_with(100, vcpus=4, memory=8192)
        assert "VM 100 resized" in result.output


def test_resize_without_options() -> None:
    """Test that resize passes None when options are omitted."""
    runner = CliRunner()
    with patch("vm_service.cli.operations.resize") as mock_resize:
        result = runner.invoke(main, ["resize", "100"])
        assert result.exit_code == 0
        mock_resize.assert_called_once_with(100, vcpus=None, memory=None)


def test_vmid_required() -> None:
    """Test that VMID is required for all commands."""
    runner = CliRunner()
    for cmd in ["create", "start", "stop", "destroy", "resize"]:
        result = runner.invoke(main, [cmd])
        assert result.exit_code != 0


def test_vmid_must_be_integer() -> None:
    """Test that VMID rejects non-integer input."""
    runner = CliRunner()
    result = runner.invoke(main, ["start", "abc"])
    assert result.exit_code != 0


def test_help_output() -> None:
    """Test that --help shows all subcommands."""
    runner = CliRunner()
    result = runner.invoke(main, ["--help"])
    assert result.exit_code == 0
    for cmd in ["create", "start", "stop", "destroy", "resize"]:
        assert cmd in result.output


def test_subcommand_help() -> None:
    """Test that each subcommand has help text."""
    runner = CliRunner()
    for cmd in ["create", "start", "stop", "destroy", "resize"]:
        result = runner.invoke(main, [cmd, "--help"])
        assert result.exit_code == 0
        assert "VMID" in result.output
