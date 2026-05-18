"""CLI commands for VM lifecycle transitions."""

import click

from vm_service import __version__, operations


@click.group()
@click.version_option(__version__, prog_name="vm-service")
def main() -> None:
    """Manage Proxmox VM lifecycle transitions."""


@main.command()
@click.argument("vmid", type=int)
@click.option("--node", default=None, help="Target Proxmox node.")
@click.option("--template", default=None, help="Proxmox template to clone.")
def create(vmid: int, node: str | None, template: str | None) -> None:
    """Create a VM by cloning a Proxmox template."""
    operations.create(vmid, node=node, template=template)
    click.echo(f"VM {vmid} created.")


@main.command()
@click.argument("vmid", type=int)
def start(vmid: int) -> None:
    """Start a VM on Proxmox."""
    operations.start(vmid)
    click.echo(f"VM {vmid} started.")


@main.command()
@click.argument("vmid", type=int)
def stop(vmid: int) -> None:
    """Stop a VM on Proxmox."""
    operations.stop(vmid)
    click.echo(f"VM {vmid} stopped.")


@main.command()
@click.argument("vmid", type=int)
def destroy(vmid: int) -> None:
    """Destroy a VM and remove DHCP/DNS entries."""
    operations.destroy(vmid)
    click.echo(f"VM {vmid} destroyed.")


@main.command()
@click.argument("vmid", type=int)
@click.option("--vcpus", type=int, default=None, help="Number of virtual CPUs.")
@click.option("--memory", type=int, default=None, help="Memory in megabytes.")
def resize(vmid: int, vcpus: int | None, memory: int | None) -> None:
    """Resize a VM's CPU and memory."""
    operations.resize(vmid, vcpus=vcpus, memory=memory)
    click.echo(f"VM {vmid} resized.")
