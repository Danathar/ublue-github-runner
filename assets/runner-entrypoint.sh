#!/usr/bin/dumb-init /bin/bash
# shellcheck shell=bash
set -euo pipefail

actions_runner_dir="${ACTIONS_RUNNER_DIR:-/actions-runner}"
image_actions_runner_dir="${IMAGE_ACTIONS_RUNNER_DIR:-/opt/actions-runner-image}"

mkdir -p "${actions_runner_dir}"

if [[ ! -x "${actions_runner_dir}/bin/Runner.Listener" ]]; then
  echo "Seeding runner files into ${actions_runner_dir}"
  cp -a "${image_actions_runner_dir}/." "${actions_runner_dir}"
fi

export RUNNER_ALLOW_RUNASROOT=1
export PATH="${PATH}:${actions_runner_dir}"

exec /entrypoint.base.sh "$@"
