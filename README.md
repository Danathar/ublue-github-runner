# Generic GitHub Runner Proposal

This folder is a proposal artifact for a generic containerized GitHub Actions
runner bootstrap on immutable Fedora-family desktops such as Bluefin, Aurora,
and uCore.

Why it is not just `docker run ghcr.io/myoung34/...`:

1. GitHub Actions `container:` jobs need the host Docker socket.
2. Immutable-root systems do not play nicely with runner state under
   `/actions-runner` when sibling job containers need host-visible mounts.
3. Keeping runner state under `~/.local/share/...` avoids that problem.

The main proposal file is [`Justfile`](./Justfile). It expects:

- Docker
- GitHub CLI `gh`
- a user already authenticated with `gh auth login`

Recommended first step:

```bash
cp .env.example .env
```

Then edit `.env` for your repo or org before the first `just up`.

Minimal repo-scoped usage:

```bash
cp .env.example .env
${EDITOR:-vi} .env
just enable-docker
just up
```

Minimal org-scoped usage:

```bash
export RUNNER_SCOPE=org
export GITHUB_ORG=example-org
just enable-docker
just up
```

The resulting container uses Docker `restart: unless-stopped`, so after
`docker.service` is enabled at boot, the runner should come back automatically
whenever the machine starts.

Security note:

- this pattern is for trusted jobs
- do not point public `pull_request` workflows at a self-hosted runner unless
  you are explicitly accepting that risk
