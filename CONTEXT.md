# vm-service

A service that lifecycle-manages Proxmox-based virtual machines.

## Language

**VM**:
A QEMU-based virtual machine managed by Proxmox. Does not include LXC containers.
_Avoid_: container, instance, node

**Lifecycle**:
The transitions vm-service owns: create → start → stop → destroy, plus resize (triggered by a NetBox update webhook when vcpus or memory changes). Pause, suspend, snapshots, and status sync are out of scope.
_Avoid_: provisioning, orchestration

**Caller**:
Any system that triggers a lifecycle transition. Primary caller is NetBox via webhook to the REST API. Secondary callers are agents via MCP and humans via CLI.

## Relationships

- **NetBox** drives lifecycle transitions via webhook: `planned` → create, `active` → start, `offline` → stop, `decommissioning` → destroy
- **MCP** and **CLI** are secondary interfaces for agent and human callers respectively
- **NetBox** is the source of truth for VM configuration (vcpus, memory, disk, custom fields), target Proxmox node, VMID, and Proxmox template name; vm-service reads all of these from the webhook payload
- **Create** means: clone a Proxmox template, apply cloud-init configuration, result is a stopped VM ready to start
- **Cloud-init config** comes entirely from NetBox: hostname from VM name, network from IP address assignments, SSH keys from custom field or config context

## Flagged ambiguities

- **Proxmox auth**: API token (`user@realm!tokenid=secret`) — not username/password ticket flow
- **Webhook auth**: HMAC-SHA512 verification via NetBox `X-Hook-Signature` header — not network-level trust
- **Failure handling**: retry N times, then write failure status back to NetBox — no silent failures
- **Operation execution**: async — webhook returns HTTP 202 immediately; vm-service polls Proxmox task status, then writes result back to NetBox
- **Networking**: all VMs land on VLAN 20; the Proxmox template carries the NIC/bridge config — vm-service does not configure networking
- **Idempotency**: all operations check current Proxmox state before acting; already-in-target-state is treated as success
- **Proxmox deployment**: single cluster; URL and API token are config/env vars at startup
- **DHCP**: managed by `dhcp-service` (HTTP API on skynet host) backed by Kea/ISC DHCP
- **DNS**: managed by `dns-service` (HTTP API on skynet host) backed by BIND for internal networks
- **DNS/DHCP lifecycle**: create registers both a DHCP reservation and DNS entry; destroy removes both; start/stop/resize do not touch DNS or DHCP
- **DNS/DHCP data**: IP from NetBox IP assignment, hostname from NetBox VM name, MAC read from Proxmox after template clone
- **Create ordering**: clone template → read MAC → register DHCP reservation → register DNS entry → start VM
- **Destroy ordering**: stop VM → remove DHCP reservation → remove DNS entry → delete VM from Proxmox
