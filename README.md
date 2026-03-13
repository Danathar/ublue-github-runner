# Repo-Scoped GitHub Runner for Universal Blue Hosts

> [!NOTE]
> This project was primarily produced with AI assistance, with manual input,
> review, and correction by the maintainer.

This repo bootstraps a repo-scoped GitHub Actions runner container for immutable
Fedora-family hosts such as Bluefin, Aurora, and uCore.

The target is a stock Universal Blue install, without writing into immutable
`/usr`.

The design is intentionally small:

- `assets/` contains the runner logic and container assets copied into the
  user's home directory
- `scripts/install-user` installs a user-space `ujust` wrapper into
  `~/.local/bin/ujust`
- `~/.config/ublue-github-runner/ujust.just` imports the stock Universal Blue
  recipes and adds `setup-github-runner`
- `Justfile` is only for repo maintenance and local installation

Why this exists instead of using the upstream runner image directly:

1. GitHub Actions `container:` jobs need the host Docker socket.
2. Runner state needs to live under the user's home directory so sibling job
   containers can see host-mounted paths on immutable systems.
3. Repo-scoped runners are the simplest safe default for this use case.

## Prerequisites

- Docker with `docker compose`
- GitHub CLI `gh`
- an existing `gh auth login`

## Usage

This works by shadowing `/usr/bin/ujust` with a wrapper in `~/.local/bin/ujust`.
That wrapper still loads the stock Universal Blue recipes from
`/usr/share/ublue-os/just/00-entry.just`, then adds this project's custom
recipe. On current Bluefin installs, `~/.local/bin` comes before `/usr/bin` in
`PATH`, so this works without touching immutable system paths.

## Install

```bash
sudo systemctl enable --now docker.service
just install-user
```

Then use it like any other Universal Blue command:

```bash
ujust setup-github-runner configure
ujust setup-github-runner install
```

Useful commands:

- `ujust setup-github-runner doctor`
- `ujust setup-github-runner status`
- `ujust setup-github-runner logs`
- `ujust setup-github-runner example`
- `ujust setup-github-runner show-config`
- `ujust setup-github-runner remove`

Configuration is stored in `~/.config/ublue-github-runner/runner.env`.
Installed assets live under `~/.local/share/ublue-github-runner`.
Runner state stays under `~/.local/share/github-actions-runner` by default.

If you want to script configuration instead of using prompts, export the desired
environment variables first and run:

```bash
ujust setup-github-runner configure-from-env
```

## Worked Example

Here is a concrete repo-scoped example for
`Danathar/automatic-parakeet`.

### 1. Install the user-space `ujust` extension

```bash
sudo systemctl enable --now docker.service
just install-user
```

### 2. Configure the runner

Run:

```bash
ujust setup-github-runner configure
```

When prompted, enter values like:

- GitHub repository: `Danathar/automatic-parakeet`
- Runner name: `automatic-parakeet-builder-$(hostname -s)`
- Runner labels: `self-hosted,linux,x64,automatic-parakeet-builder`
- Runner home: `/var/home/$USER/.local/share/automatic-parakeet-runner`
- Runner container name: `github-actions-runner-danathar-automatic-parakeet`
- Runner image name: `local/github-actions-runner:danathar-automatic-parakeet`

That writes:

```dotenv
GITHUB_REPOSITORY=Danathar/automatic-parakeet
RUNNER_NAME=automatic-parakeet-builder-yourhost
RUNNER_LABELS=self-hosted,linux,x64,automatic-parakeet-builder
RUNNER_HOME=/var/home/youruser/.local/share/automatic-parakeet-runner
RUNNER_CONTAINER_NAME=github-actions-runner-danathar-automatic-parakeet
RUNNER_IMAGE_NAME=local/github-actions-runner:danathar-automatic-parakeet
```

to `~/.config/ublue-github-runner/runner.env`.

You can also edit that file manually instead of using the prompt.

### 3. Verify prerequisites

```bash
ujust setup-github-runner doctor
```

This should confirm:

- `docker` works
- `docker compose` works
- `gh` is authenticated
- the runner directories can be created under your home directory

### 4. Install and start the runner

```bash
ujust setup-github-runner install
```

This will:

1. request a fresh repo registration token from GitHub
2. build the local runner wrapper image
3. start the runner container with Docker restart policy `unless-stopped`
4. register the runner against `Danathar/automatic-parakeet`

### 5. Verify runner status

```bash
ujust setup-github-runner status
```

You should see:

- the local runner container
- the GitHub runner registration for `automatic-parakeet-builder-yourhost`

If you want the tool to print the workflow label example directly:

```bash
ujust setup-github-runner example
```

### 6. Point trusted workflows at the runner

This tool only creates the runner. It does not modify the target repository's
workflows.

In `Danathar/automatic-parakeet`, trusted jobs would need to use something like:

```yaml
runs-on: [self-hosted, linux, x64, automatic-parakeet-builder]
```

Keep public `pull_request` jobs on GitHub-hosted runners unless you explicitly
want untrusted PR code to run on your own machine.

### 7. Reboot behavior

Because Docker is enabled at boot and the runner container uses
`restart: unless-stopped`, the runner should come back automatically whenever
the host reboots.

## What This Tool Does Not Do

- It does not edit the target repo's workflow YAML.
- It does not decide which jobs are safe to run on self-hosted infrastructure.
- It does not install `gh` or Docker for you.
- It does not make public PR execution safe.

## Remove

```bash
just uninstall-user
```

## Development

The root `Justfile` keeps the same maintenance-oriented recipes used in
Universal Blue repos:

- `just check`
- `just fix`
- `just lint`
- `just format`
- `just install-user`
- `just uninstall-user`

## Security

This pattern is for trusted jobs. Do not route untrusted public pull requests
to a self-hosted runner unless you explicitly accept that risk.
