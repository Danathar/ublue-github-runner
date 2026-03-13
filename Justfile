set unstable := true

[private]
default:
    @just --list

# Check Just syntax.
[group('Just')]
check:
    #!/usr/bin/env bash
    set -euo pipefail
    just --unstable --fmt --check -f Justfile
    just --unstable --fmt --check -f assets/ujust.just

# Format the Justfile.
[group('Just')]
fix:
    #!/usr/bin/env bash
    set -euo pipefail
    just --unstable --fmt -f Justfile
    just --unstable --fmt -f assets/ujust.just

# Run shellcheck on project scripts.
[group('Quality')]
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v shellcheck >/dev/null || { echo "shellcheck is required"; exit 1; }
    shellcheck \
      ./assets/runner \
      ./assets/runner-entrypoint.sh \
      ./scripts/install-user \
      ./scripts/uninstall-user

# Format shell scripts in place.
[group('Quality')]
format:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v shfmt >/dev/null || { echo "shfmt is required"; exit 1; }
    shfmt -w \
      ./assets/runner \
      ./assets/runner-entrypoint.sh \
      ./scripts/install-user \
      ./scripts/uninstall-user

# Install the user-space ujust wrapper and assets.
[group('Install')]
install-user:
    ./scripts/install-user

# Remove the user-space ujust wrapper and assets.
[group('Install')]
uninstall-user:
    ./scripts/uninstall-user
