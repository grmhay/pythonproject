# PRD: VM Lifecycle Management

## Problem Statement

Managing Proxmox VMs manually is error-prone and slow. When an operator creates or decommissions a VM in NetBox, they must separately provision the QEMU VM on Proxmox, register a DHCP reservation with Kea, create a DNS entry in BIND, and configure cloud-init — or reverse all of that on teardown. There is no single service that owns this workflow, so steps get missed and environments drift from NetBox's declared state.

## Solution

vm-service is a lifecycle manager that listens for NetBox webhook events and faithfully executes the corresponding Proxmox, DHCP, and DNS operations. When an operator changes a VM's status in NetBox, vm-service takes care of everything else: cloning the template, registering network identity, applying cloud-init, and starting the VM — or reversing all of that on decommission. Operators declare intent in NetBox; vm-service makes it real.

## User Stories

1. As a NetBox operator, I want a VM to be automatically provisioned on Proxmox when I set its status to `planned`, so that I don't have to manually clone templates.
2. As a NetBox operator, I want cloud-init to be applied from NetBox data during provisioning, so that the VM boots with the correct hostname, IP, and SSH keys.
3. As a NetBox operator, I want a DHCP reservation to be created automatically when a VM is provisioned, so that the VM receives its designated IP on boot.
4. As a NetBox operator, I want a DNS entry to be created automatically when a VM is provisioned, so that the VM is reachable by hostname immediately.
5. As a NetBox operator, I want the VM to start automatically after provisioning completes, so that I don't need a second manual step.
6. As a NetBox operator, I want a VM to start on Proxmox when I set its status to `active`, so that I can control power state from NetBox.
7. As a NetBox operator, I want a VM to stop on Proxmox when I set its status to `offline`, so that I can shut it down without accessing Proxmox directly.
8. As a NetBox operator, I want a VM to be destroyed on Proxmox when I set its status to `decommissioning`, so that I can fully retire a VM from NetBox alone.
9. As a NetBox operator, I want the DHCP reservation to be removed automatically when a VM is destroyed, so that the IP is freed without manual cleanup.
10. As a NetBox operator, I want the DNS entry to be removed automatically when a VM is destroyed, so that stale DNS records don't accumulate.
11. As a NetBox operator, I want a VM's CPU and memory to be updated on Proxmox when I change them in NetBox, so that resizing doesn't require Proxmox access.
12. As a NetBox operator, I want the VM status in NetBox to be set to `failed` if a lifecycle operation fails, so that I know something went wrong without checking logs.
13. As a NetBox operator, I want failed operations to be retried automatically, so that transient Proxmox or network errors don't leave VMs in a broken state.
14. As a NetBox operator, I want duplicate webhook deliveries to be handled safely, so that a NetBox retry doesn't create duplicate VMs or cause errors.
15. As a platform engineer, I want all incoming webhooks to be HMAC-verified, so that only legitimate NetBox events trigger infrastructure changes.
16. As a platform engineer, I want vm-service to authenticate to Proxmox using an API token, so that credentials can be scoped and rotated independently.
17. As a platform engineer, I want vm-service configured entirely via environment variables, so that it can run in any environment without config file management.
18. As an agent, I want MCP tools for each lifecycle transition, so that I can manage VMs programmatically during automation workflows.
19. As a human operator, I want CLI commands for each lifecycle transition, so that I can trigger operations without sending raw HTTP requests.
20. As a platform engineer, I want webhook operations to return HTTP 202 immediately, so that NetBox doesn't time out waiting for long-running Proxmox tasks.

## Implementation Decisions

### Modules

**Deep modules** (rich behaviour, simple interface, tested in isolation):

- **`proxmox.py`** — wraps the Proxmox API for all VM operations: clone template, read VM config (including MAC), start, stop, delete, resize (vcpus/memory), get current power state, poll task status until completion. Single point of contact with Proxmox.

- **`netbox.py`** — reads VM configuration from NetBox (vcpus, memory, disk, template name, target node, VMID, IP assignment, SSH keys, config context) and writes VM status back. Single point of contact with NetBox.

- **`webhook.py`** — parses the incoming NetBox webhook payload, verifies the HMAC-SHA512 signature against the shared secret, and maps NetBox VM status values to lifecycle transitions (`planned`→create, `active`→start, `offline`→stop, `decommissioning`→destroy). Pure logic with no I/O.

- **`dhcp_client.py`** — wraps the dhcp-service HTTP API on skynet: create and delete DHCP reservations by MAC and IP.

- **`dns_client.py`** — wraps the dns-service HTTP API on skynet: create and delete DNS A records by hostname and IP.

- **`operations.py`** — orchestrates complete lifecycle transitions. For each transition, calls the appropriate sequence of proxmox, netbox, dhcp_client, and dns_client operations, handles retries, polls Proxmox task status, and writes the final result back to NetBox. Background task entry point for the API.

**Shallow modules** (thin wires, minimal logic):

- **`config.py`** — loads all configuration from environment variables: Proxmox URL, API token, NetBox URL, NetBox token, webhook secret, dhcp-service URL, dns-service URL, retry count.

- **`api.py`** — FastAPI app with a single `POST /webhook` endpoint. Verifies HMAC via `webhook.py`, returns 202, fires a background task via `operations.py`.

- **`mcp_server.py`** — FastMCP tools for each transition: create, start, stop, destroy, resize. Delegates to `operations.py`.

- **`cli.py`** — Click commands for each transition. Delegates to `operations.py`.

### Operation sequences

**Create**: clone Proxmox template (using VMID, template name, and target node from NetBox) → apply cloud-init (hostname, IP, gateway, SSH keys from NetBox) → read MAC from Proxmox → register DHCP reservation (MAC + IP via dhcp-service) → register DNS A record (hostname + IP via dns-service) → start VM → write `active` back to NetBox.

**Start**: check Proxmox power state → if already running, return success → otherwise start VM, poll until running → write `active` back to NetBox.

**Stop**: check Proxmox power state → if already stopped, return success → otherwise stop VM, poll until stopped → write `offline` back to NetBox.

**Destroy**: stop VM (if running) → remove DHCP reservation → remove DNS entry → delete VM from Proxmox → write `decommissioning` back to NetBox (or mark complete).

**Resize**: stop VM if running → apply new vcpus/memory to Proxmox VM config → restart VM → write status back to NetBox.

### Idempotency

Before every operation, vm-service checks current Proxmox state. If the VM is already in the target state, the operation returns success without acting. This makes all transitions safe to retry and handles duplicate webhook deliveries.

### Async execution

The `POST /webhook` endpoint returns HTTP 202 immediately. The actual operation runs as a FastAPI background task. Proxmox task IDs are polled until the task completes or times out.

### Failure handling

Operations are retried up to a configurable number of times (env var). On final failure, vm-service sets the NetBox VM status to `failed`. No silent failures.

### Authentication

- **Proxmox**: API token in `user@realm!tokenid=secret` format, passed as `Authorization` header.
- **NetBox webhook**: HMAC-SHA512 of the raw request body using a shared secret, verified against `X-Hook-Signature` header.
- **dhcp-service / dns-service**: authentication mechanism TBD when those service APIs are documented.

### Configuration (env vars)

`PROXMOX_URL`, `PROXMOX_TOKEN_ID`, `PROXMOX_TOKEN_SECRET`, `NETBOX_URL`, `NETBOX_TOKEN`, `WEBHOOK_SECRET`, `DHCP_SERVICE_URL`, `DNS_SERVICE_URL`, `OPERATION_RETRY_COUNT`.

## Testing Decisions

A good test exercises the module's external behaviour — what it returns or what calls it makes — not its internal implementation. Tests should not assert on private methods, internal state, or log output.

### Modules to test

- **`webhook.py`** — test payload parsing, HMAC verification (valid secret, wrong secret, missing header), and status→transition mapping. No mocking needed; pure functions.

- **`proxmox.py`** — test each operation (clone, start, stop, delete, resize, get_state, poll_task) by mocking the HTTP client. Assert correct API calls are made and responses are parsed correctly.

- **`netbox.py`** — test VM config extraction and status write-back by mocking the NetBox HTTP client. Assert the right fields are read and the right PATCH calls are made.

- **`dhcp_client.py`** — test create and delete reservation by mocking the dhcp-service HTTP client.

- **`dns_client.py`** — test create and delete DNS entry by mocking the dns-service HTTP client.

- **`operations.py`** — test each full transition end-to-end by mocking all four clients (proxmox, netbox, dhcp_client, dns_client). Assert correct sequencing, retry behaviour, and failure write-back.

### Prior art

`tests/test_mcp_server.py` uses `pytest-anyio` with `async with Client(mcp)` for async MCP tests. Use the same `@pytest.mark.anyio` pattern for any async tests in operations.

## Out of Scope

- LXC container management
- Pause and suspend transitions
- Multi-cluster Proxmox routing
- Snapshot management
- Periodic status sync from Proxmox to NetBox
- VM networking configuration (bridge, VLAN) — all VMs land on VLAN 20 via the template
- Node selection / scheduling — NetBox specifies the target node

## Further Notes

- The MAC address for the DHCP reservation must be read from Proxmox *after* the template clone, not before, since Proxmox assigns it during the clone operation.
- DHCP and DNS registration must complete before the VM is started, so the VM receives its correct IP on first boot.
- The dhcp-service and dns-service APIs are internal services on the `skynet` host — their exact API contracts will need to be confirmed before implementing those client modules.
