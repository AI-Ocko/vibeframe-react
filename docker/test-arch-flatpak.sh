#!/bin/bash

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

BUNDLE_PATH="${BUNDLE_PATH:-$PROJECT_ROOT/flatpak-build/Quantframe-x86_64-test.flatpak}"
if [ ! -f "$BUNDLE_PATH" ]; then
  echo "Flatpak bundle not found at: $BUNDLE_PATH" >&2
  echo "Build one first with: flatpak build-bundle flatpak-build/repo <out>.flatpak dev.kenya.quantframe" >&2
  exit 1
fi
BUNDLE_NAME="$(basename "$BUNDLE_PATH")"

# Build the Docker image
echo "Building Docker image (Arch + Flatpak)..."
docker build -f "$SCRIPT_DIR/Dockerfile.arch-flatpak" -t quantframe-react:arch-flatpak "$PROJECT_ROOT"

# Run the container with the bundle mounted, install it, and verify.
# --privileged is required for nested user namespaces / bwrap inside Docker.
echo ""
echo "Installing flatpak bundle inside Arch container..."
docker run --rm \
  --privileged \
  -v "$BUNDLE_PATH:/bundle/$BUNDLE_NAME:ro" \
  quantframe-react:arch-flatpak \
  bash -c "
    set -e
    echo '--- flatpak version ---'
    flatpak --version
    echo '--- installing bundle ---'
    flatpak install -y --noninteractive /bundle/$BUNDLE_NAME
    echo '--- flatpak info ---'
    flatpak info dev.kenya.quantframe
    echo '--- installed binary ---'
    flatpak run --command=sh dev.kenya.quantframe -c 'ls -la /app/bin && file /app/bin/Quantframe && echo --- ldd --- && ldd /app/bin/Quantframe | head -40'
  "

echo ""
echo "Install test passed."
