"""Lifecycle operations for Proxmox VMs."""


def create(vmid: int, *, node: str | None = None, template: str | None = None) -> None:
    """Create a VM by cloning a Proxmox template.

    Args:
        vmid: The globally unique VM ID.
        node: Target Proxmox node. Fetched from NetBox if not provided.
        template: Proxmox template to clone. Fetched from NetBox if not provided.
    """
    msg = "create operation not yet implemented"
    raise NotImplementedError(msg)


def start(vmid: int) -> None:
    """Start a VM on Proxmox.

    Args:
        vmid: The globally unique VM ID.
    """
    msg = "start operation not yet implemented"
    raise NotImplementedError(msg)


def stop(vmid: int) -> None:
    """Stop a VM on Proxmox.

    Args:
        vmid: The globally unique VM ID.
    """
    msg = "stop operation not yet implemented"
    raise NotImplementedError(msg)


def destroy(vmid: int) -> None:
    """Destroy a VM, removing DHCP and DNS entries.

    Args:
        vmid: The globally unique VM ID.
    """
    msg = "destroy operation not yet implemented"
    raise NotImplementedError(msg)


def resize(vmid: int, *, vcpus: int | None = None, memory: int | None = None) -> None:
    """Resize a VM's CPU and memory on Proxmox.

    Args:
        vmid: The globally unique VM ID.
        vcpus: Number of virtual CPUs.
        memory: Memory in megabytes.
    """
    msg = "resize operation not yet implemented"
    raise NotImplementedError(msg)
