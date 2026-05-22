#!/bin/bash

# Build the Flatpak from source inside an Ubuntu container that already has
# flatpak-builder + the GNOME 49 SDK and rust/node SDK extensions installed,
# then install the resulting bundle in the same container and sanity-check it.
#
# This complements docker/test-arch-flatpak.sh — that script only tests
# *installing* a pre-built bundle on a minimal Arch runtime. This one tests
# the full *build* path on Ubuntu and then installs the freshly built bundle.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Building Docker image (Ubuntu + Flatpak)..."
docker build -f "$SCRIPT_DIR/Dockerfile.ubuntu-flatpak" -t quantframe-react:ubuntu-flatpak "$PROJECT_ROOT"

# We run flatpak-builder + flatpak install inside the container. Both need
# nested user namespaces (bwrap), so --privileged is required under Docker.
#
# The project is mounted read-write so flatpak-builder can use its standard
# .flatpak-builder cache directory at the project root for incremental builds
# across runs. Set FRESH=1 to wipe that cache before building.
echo ""
echo "Building + installing Quantframe Flatpak inside Ubuntu container..."
docker run --rm \
  --privileged \
  -v "$PROJECT_ROOT:/app" \
  -e FRESH="${FRESH:-0}" \
  quantframe-react:ubuntu-flatpak \
  bash -c '
    set -e
    cd /app

    if [ "$FRESH" = "1" ]; then
      echo "FRESH=1 — wiping .flatpak-builder cache"
      rm -rf .flatpak-builder build-dir-ubuntu
    fi

    echo "--- flatpak-builder version ---"
    flatpak-builder --version

    echo "--- building manifest ---"
    flatpak-builder \
      --user \
      --force-clean \
      --repo=flatpak-build/repo-ubuntu \
      build-dir-ubuntu \
      packaging/flatpak/dev.kenya.quantframe.yml

    echo "--- exporting bundle ---"
    mkdir -p flatpak-build
    flatpak build-bundle \
      flatpak-build/repo-ubuntu \
      flatpak-build/Quantframe-ubuntu-test.flatpak \
      dev.kenya.quantframe

    echo "--- installing bundle ---"
    flatpak install -y --noninteractive flatpak-build/Quantframe-ubuntu-test.flatpak

    echo "--- flatpak info ---"
    flatpak info dev.kenya.quantframe

    echo "--- starting system dbus daemon ---"
    mkdir -p /run/dbus
    dbus-daemon --system --fork
    sleep 1

    echo "--- ldd sanity check on installed binary ---"
    dbus-run-session -- flatpak run --command=sh dev.kenya.quantframe -c "
      file /app/bin/Quantframe
      echo --- missing libs ---
      ldd /app/bin/Quantframe | grep -E \"not found\" || echo \"(none)\"
    "

    echo "--- launching under xvfb (12s) ---"
    timeout --preserve-status -k 2 12 dbus-run-session -- \
      xvfb-run -a -s "-screen 0 1280x800x24" \
      flatpak run dev.kenya.quantframe 2>&1 | tee /tmp/qf.log | tail -40 || true

    echo
    echo "--- error / panic grep ---"
    grep -Ei "panic|segfault|undefined symbol|cannot open shared" /tmp/qf.log || echo "(none)"
  '

echo ""
echo "Ubuntu build + install test passed."
echo "  - Built bundle: flatpak-build/Quantframe-ubuntu-test.flatpak"
echo "  - Local repo:   flatpak-build/repo-ubuntu/"
