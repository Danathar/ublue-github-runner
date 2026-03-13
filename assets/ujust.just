import? "/usr/share/ublue-os/just/00-entry.just"

[group('System')]
setup-github-runner action="prompt":
    # Keep the recipe itself tiny.
    # The real logic lives in the installed runner script under ~/.local/share.
    #!/usr/bin/env bash
    set -euo pipefail
    exec "${XDG_DATA_HOME:-$HOME/.local/share}/ublue-github-runner/runner" "{{ action }}"
