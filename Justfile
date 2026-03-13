set unstable := true
set dotenv-load := true

# Generic GitHub Actions runner bootstrap for immutable Fedora-family desktops
# such as Bluefin, Aurora, and uCore.
#
# Required environment for a repo-scoped runner:
#   export GITHUB_REPOSITORY=owner/repo
#
# Optional overrides:
#   export RUNNER_SCOPE=repo
#   export GITHUB_ORG=your-org
#   export REPO_URL=https://github.com/owner/repo
#   export RUNNER_NAME=github-runner-$(hostname -s)
#   export RUNNER_LABELS=self-hosted,linux,x64
#   export RUNNER_IMAGE_NAME=local/github-actions-runner:bluefin
#   export RUNNER_CONTAINER_NAME=github-actions-runner
#   export RUNNER_HOME=$HOME/.local/share/github-actions-runner
#
# This stores runner state under the user's home directory instead of
# /actions-runner so sibling job containers can mount host-visible paths without
# depending on the immutable root filesystem.

default:
  @just --list

check:
  #!/usr/bin/env bash
  set -euo pipefail
  command -v docker >/dev/null || { echo "docker is required"; exit 1; }
  command -v gh >/dev/null || { echo "gh is required"; exit 1; }
  docker version >/dev/null
  gh auth status >/dev/null
  echo "docker and gh are available"

enable-docker:
  #!/usr/bin/env bash
  set -euo pipefail
  sudo systemctl enable --now docker.service
  systemctl is-enabled docker.service
  systemctl is-active docker.service

bootstrap-dirs:
  #!/usr/bin/env bash
  set -euo pipefail
  runner_home="${RUNNER_HOME:-${HOME}/.local/share/github-actions-runner}"
  mkdir -p \
    "${runner_home}/actions-runner" \
    "${runner_home}/work" \
    "${runner_home}/toolcache"
  echo "Runner home: ${runner_home}"

build-image: bootstrap-dirs
  #!/usr/bin/env bash
  set -euo pipefail
  image_name="${RUNNER_IMAGE_NAME:-local/github-actions-runner:bluefin}"
  docker build \
    -t "${image_name}" \
    -f ./Dockerfile.runner \
    .
  echo "Built ${image_name}"

up: check build-image
  #!/usr/bin/env bash
  set -euo pipefail

  runner_scope="${RUNNER_SCOPE:-repo}"
  runner_scope="${runner_scope,,}"
  runner_home="${RUNNER_HOME:-${HOME}/.local/share/github-actions-runner}"
  runner_install_dir="${RUNNER_INSTALL_DIR:-${runner_home}/actions-runner}"
  runner_workdir="${RUNNER_WORKDIR:-${runner_home}/work}"
  runner_toolcache_dir="${RUNNER_TOOLCACHE_DIR:-${runner_home}/toolcache}"
  runner_image_name="${RUNNER_IMAGE_NAME:-local/github-actions-runner:bluefin}"
  runner_container_name="${RUNNER_CONTAINER_NAME:-github-actions-runner}"
  runner_name="${RUNNER_NAME:-github-runner-$(hostname -s)}"
  runner_labels="${RUNNER_LABELS:-self-hosted,linux,x64}"
  repo_url="${REPO_URL:-}"

  case "${runner_scope}" in
    repo)
      github_repository="${GITHUB_REPOSITORY:-}"
      [[ -n "${github_repository}" ]] || {
        echo "GITHUB_REPOSITORY is required for repo-scoped runners"
        exit 1
      }
      if [[ -z "${repo_url}" ]]; then
        repo_url="https://github.com/${github_repository}"
      fi
      token_endpoint="repos/${github_repository}/actions/runners/registration-token"
      ;;
    org)
      github_org="${GITHUB_ORG:-}"
      [[ -n "${github_org}" ]] || {
        echo "GITHUB_ORG is required for org-scoped runners"
        exit 1
      }
      token_endpoint="orgs/${github_org}/actions/runners/registration-token"
      ;;
    *)
      echo "Unsupported RUNNER_SCOPE: ${runner_scope}"
      exit 1
      ;;
  esac

  runner_token="$(gh api -X POST "${token_endpoint}" --jq .token)"

  docker rm -f "${runner_container_name}" >/dev/null 2>&1 || true

  docker run -d \
    --name "${runner_container_name}" \
    --restart unless-stopped \
    --user root \
    -e ACTIONS_RUNNER_DIR="${runner_install_dir}" \
    -e IMAGE_ACTIONS_RUNNER_DIR=/opt/actions-runner-image \
    -e AGENT_TOOLSDIRECTORY="${runner_toolcache_dir}" \
    -e RUN_AS_ROOT=true \
    -e RUNNER_SCOPE="${runner_scope}" \
    -e REPO_URL="${repo_url}" \
    -e ORG_NAME="${GITHUB_ORG:-}" \
    -e RUNNER_NAME="${runner_name}" \
    -e LABELS="${runner_labels}" \
    -e RUNNER_WORKDIR="${runner_workdir}" \
    -e DISABLE_AUTOMATIC_DEREGISTRATION=true \
    -e DISABLE_AUTO_UPDATE=1 \
    -e UNSET_CONFIG_VARS=true \
    -e RUNNER_TOKEN="${runner_token}" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${runner_install_dir}:${runner_install_dir}" \
    -v "${runner_workdir}:${runner_workdir}" \
    -v "${runner_toolcache_dir}:${runner_toolcache_dir}" \
    "${runner_image_name}"

  docker ps --filter "name=${runner_container_name}"
  just status

start:
  #!/usr/bin/env bash
  set -euo pipefail
  runner_container_name="${RUNNER_CONTAINER_NAME:-github-actions-runner}"
  docker start "${runner_container_name}"
  just status

stop:
  #!/usr/bin/env bash
  set -euo pipefail
  runner_container_name="${RUNNER_CONTAINER_NAME:-github-actions-runner}"
  docker stop "${runner_container_name}"

logs:
  #!/usr/bin/env bash
  set -euo pipefail
  runner_container_name="${RUNNER_CONTAINER_NAME:-github-actions-runner}"
  docker logs --tail 100 -f "${runner_container_name}"

status:
  #!/usr/bin/env bash
  set -euo pipefail

  runner_scope="${RUNNER_SCOPE:-repo}"
  runner_scope="${runner_scope,,}"
  runner_name="${RUNNER_NAME:-github-runner-$(hostname -s)}"
  runner_container_name="${RUNNER_CONTAINER_NAME:-github-actions-runner}"

  docker ps --filter "name=${runner_container_name}"

  case "${runner_scope}" in
    repo)
      github_repository="${GITHUB_REPOSITORY:-}"
      [[ -n "${github_repository}" ]] || exit 0
      gh api "repos/${github_repository}/actions/runners" \
        --jq '.runners[] | select(.name == "'"${runner_name}"'") | {name: .name, status: .status, busy: .busy, labels: [.labels[].name]}'
      ;;
    org)
      github_org="${GITHUB_ORG:-}"
      [[ -n "${github_org}" ]] || exit 0
      gh api "orgs/${github_org}/actions/runners" \
        --jq '.runners[] | select(.name == "'"${runner_name}"'") | {name: .name, status: .status, busy: .busy, labels: [.labels[].name]}'
      ;;
  esac

unregister:
  #!/usr/bin/env bash
  set -euo pipefail

  runner_scope="${RUNNER_SCOPE:-repo}"
  runner_scope="${runner_scope,,}"
  runner_name="${RUNNER_NAME:-github-runner-$(hostname -s)}"

  case "${runner_scope}" in
    repo)
      github_repository="${GITHUB_REPOSITORY:-}"
      [[ -n "${github_repository}" ]] || {
        echo "GITHUB_REPOSITORY is required for repo-scoped unregister"
        exit 1
      }
      runner_id="$(
        gh api "repos/${github_repository}/actions/runners" \
          --jq '.runners[] | select(.name == "'"${runner_name}"'") | .id'
      )"
      [[ -n "${runner_id}" ]] || {
        echo "Runner ${runner_name} is not registered in ${github_repository}"
        exit 0
      }
      gh api -X DELETE "repos/${github_repository}/actions/runners/${runner_id}"
      ;;
    org)
      github_org="${GITHUB_ORG:-}"
      [[ -n "${github_org}" ]] || {
        echo "GITHUB_ORG is required for org-scoped unregister"
        exit 1
      }
      runner_id="$(
        gh api "orgs/${github_org}/actions/runners" \
          --jq '.runners[] | select(.name == "'"${runner_name}"'") | .id'
      )"
      [[ -n "${runner_id}" ]] || {
        echo "Runner ${runner_name} is not registered in ${github_org}"
        exit 0
      }
      gh api -X DELETE "orgs/${github_org}/actions/runners/${runner_id}"
      ;;
    *)
      echo "Unsupported RUNNER_SCOPE: ${runner_scope}"
      exit 1
      ;;
  esac

remove:
  #!/usr/bin/env bash
  set -euo pipefail
  runner_container_name="${RUNNER_CONTAINER_NAME:-github-actions-runner}"
  docker rm -f "${runner_container_name}" >/dev/null 2>&1 || true
