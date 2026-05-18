# vm-service

A Python application with CLI and API.

## Develop

Enter the Nix shell with:

```sh
nix develop
```

Then run the tests with:

```sh
nox
```

To see the available sessions, run:

```sh
nox --list
```

To format the codebase:

```sh
nox -s format -- --fix
```

## Build

To check and build the package, run:

```sh
nix build
```

## Run

Inside `nix develop`, run the CLI:

```sh
vm-service --name=there --count=3
```

Start the API server:

```sh
vm-service-api
```

The API will be available at <http://localhost:8000>.
Docs at <http://localhost:8000/docs>.

## Sandbox Loop

The Sandbox Loop runs Claude Code against GitHub Issues labelled `ready-for-agent`, implements them inside an isolated Docker container, and opens a pull request per issue.

### First-time setup

Copy `.sandcastle/.env.example` to `.sandcastle/.env` and fill in your credentials:

```sh
cp .sandcastle/.env.example .sandcastle/.env
```

Build the sandbox Docker image (only needed once, or after editing `.sandcastle/Dockerfile`):

```sh
npx sandcastle docker build-image
```

### Running the loop

1. Apply the `ready-for-agent` label to any fully-specified issue
2. Run the loop:
   ```sh
   npm run sandcastle
   ```
3. The agent opens a PR per issue and moves the label from `ready-for-agent` to `ready-for-human`
4. Review and merge the PR

### Prerequisites

- Docker running locally
- `gh` CLI authenticated (`gh auth login`)
- `ANTHROPIC_API_KEY` and `GITHUB_TOKEN` set in `.sandcastle/.env`
