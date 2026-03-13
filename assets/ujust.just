import? "/usr/share/ublue-os/just/00-entry.just"

[group('System')]
setup-github-runner action="prompt":
    #!/usr/bin/env bash
    set -euo pipefail
    exec "${XDG_DATA_HOME:-$HOME/.local/share}/ublue-github-runner/runner" "{{ action }}"
