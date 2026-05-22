# Changelog

All notable packaging and distribution changes are documented in this file.

## [Unreleased] - 2026-05-21

### Added — Ubuntu Flatpak build + install test in Docker

Added a companion to the Arch test that exercises the *build* path on
Ubuntu: it runs `flatpak-builder` against the manifest, bundles the
result, installs that bundle, and launches it — all inside one
container. The Arch test covers "does the bundle install on a minimal
runtime"; this one covers "can a clean Ubuntu environment build the
Flatpak from source and run it".

- **`docker/Dockerfile.ubuntu-flatpak`** — extended the existing image
  with `ca-certificates`, `xvfb`, and explicit apt cleanup, plus a
  `WORKDIR /app`. The base packages (`flatpak`, `flatpak-builder`,
  GNOME 49 SDK + rust-stable/node22 SDK extensions) were already
  installed.
- **`docker/test-ubuntu-flatpak.sh`** — `--privileged` container that
  mounts the project read-write (so `.flatpak-builder/` and
  `src-tauri/target/` cache across runs), then:
  1. `flatpak-builder --repo=flatpak-build/repo-ubuntu build-dir-ubuntu …`
  2. `flatpak build-bundle … Quantframe-ubuntu-test.flatpak`
  3. `flatpak install` of the freshly built bundle
  4. starts the system D-Bus daemon, then runs `ldd` inside the
     sandbox to check for missing libraries
  5. launches the app under `dbus-run-session` + `xvfb-run` with a
     12-second budget and greps the log for `panic|segfault|undefined
     symbol|cannot open shared`
  Pass `FRESH=1` to wipe the builder cache before building.

D-Bus notes:

- `flatpak run` (system installs) needs both a system bus and a session
  bus. Started the system daemon with `dbus-daemon --system --fork`,
  and used `dbus-run-session` to provide the session bus per-invocation.
  Without this the run fails with `error: Could not connect: No such
  file or directory`.

Test results:

- `flatpak-builder` completed cleanly inside the container, AppStream
  compose succeeded, both `dev.kenya.quantframe` and
  `dev.kenya.quantframe.Debug` were committed to the local repo.
- Bundle install succeeded; `flatpak info` returned the expected ref
  and runtime (`org.gnome.Platform/x86_64/49`).
- `ldd /app/bin/Quantframe` inside the sandbox: no missing libs.
- App launched under xvfb, reached its main loop (DB migrations
  applied, file watcher running), exited via the 12-second timeout.
  No panics, no missing symbols. Same benign warnings as the Arch
  test (empty tokens, no `EE.log`, no GPU/DRI3).

Run the test with: `./docker/test-ubuntu-flatpak.sh`

## [Unreleased] - 2026-05-21

### Added — Arch Linux Flatpak install test in Docker

Added a Docker-based smoke test that verifies the Flatpak bundle installs
and launches cleanly on a fresh Arch Linux system with only the GNOME 49
runtime preinstalled. This complements the existing Ubuntu/Fedora native
build containers by exercising the Flatpak distribution path on a third
distro, and provides a reproducible way to catch missing runtime deps
before publishing a bundle.

- **`docker/Dockerfile.arch-flatpak`** — `archlinux:latest` base with
  `flatpak`, `git`, `ca-certificates`, `dbus`, `fuse2`, `xdg-utils`, and
  `xorg-server-xvfb` installed. Pre-pulls the `flathub` remote and
  `org.gnome.Platform//49` (plus its GL / VAAPI / codecs / locale
  sub-runtimes). The SDK and SDK extensions are intentionally omitted —
  those are build-only, and excluding them verifies that the bundle's
  declared runtime is genuinely self-sufficient at install/launch time.
- **`docker/test-arch-flatpak.sh`** — mirrors `build-ubuntu.sh` /
  `build-fedora.sh`. Builds the image, mounts the bundle at
  `flatpak-build/Quantframe-x86_64-test.flatpak` (overridable via
  `BUNDLE_PATH`) into the container read-only, then runs
  `flatpak install` + `flatpak info` + an `ldd` sanity check on the
  installed `/app/bin/Quantframe`. Uses `--privileged` because bwrap
  needs nested user namespaces inside Docker.

Test results on the bundle built from the current manifest:

- Install: `flatpak install` succeeded, `flatpak info` returned the
  expected ref, `ldd` resolved every library against the GNOME 49
  sandbox (no missing symbols).
- Launch: under `xvfb-run` with a 15-second timeout, the app reached
  its main loop — DB backup created, migrations applied, file watcher
  started polling for `EE.log`. No panics, no crashes, no missing
  libraries. Expected non-blocking warnings only: empty user tokens
  (no saved credentials in the fresh container), `EE.log not found`
  (Warframe not installed), `IBUS-WARNING` about a missing
  `/var/lib/dbus/machine-id`, and a `libEGL DRI3` warning (no GPU
  passthrough). None of these indicate packaging issues.

Run the test with: `./docker/test-arch-flatpak.sh`

## [Unreleased] - 2026-05-20

### Fixed — Warframe `EE.log` discovery on Linux / Flatpak

The log parser previously resolved its default path via Tauri's
`local_data_dir()` joined with `Warframe/EE.log`. On Linux this expands
to `~/.local/share/Warframe/EE.log`, which does not exist — Warframe
runs under Steam Proton and writes its log inside the Proton prefix.
Under Flatpak the parser logged
`File not found: /home/.../dev.kenya.quantframe/data/Warframe/EE.log`
and never picked up trade events.

- **`src-tauri/src/log_parser/client.rs`** — `LogParserState::get_default_path`
  is now platform-aware. On Linux it resolves to the Steam Proton prefix
  for Warframe (Steam app id `230410`), checking the native Steam install
  at `~/.local/share/Steam/steamapps/compatdata/230410/pfx/drive_c/users/steamuser/AppData/Local/Warframe/EE.log`
  first, then the Flatpak Steam install at
  `~/.var/app/com.valvesoftware.Steam/data/Steam/...`. If neither file
  exists yet (Warframe never launched), it falls back to the native path
  so the file watcher picks it up on first appearance. Windows behavior
  is unchanged (`local_data_dir/Warframe/EE.log`).
- **`src-tauri/src/helper.rs`** — added `get_home_path()` helper
  (mirrors the existing `get_local_data_path()` pattern) so the log
  parser can resolve `$HOME` without pulling in `tauri::Manager`
  directly.
- **`packaging/flatpak/dev.kenya.quantframe.yml`** — added two
  narrowly-scoped read-only `--filesystem=` permissions to `finish-args`
  so the sandbox can actually read `EE.log` from either Steam install
  location:
  - `~/.local/share/Steam/steamapps/compatdata/230410/pfx/drive_c/users/steamuser/AppData/Local/Warframe:ro`
  - `~/.var/app/com.valvesoftware.Steam/data/Steam/steamapps/compatdata/230410/pfx/drive_c/users/steamuser/AppData/Local/Warframe:ro`

  These are scoped to the Warframe directory specifically (not the whole
  Steam tree) and are read-only since the parser only watches the file.
  Users who override the path via the `wf_log_path` advanced setting will
  still need their chosen location to fall under an existing whitelisted
  path (e.g. `xdg-download` / `xdg-documents`).

A rebuild of the Flatpak is required to pick up the new finish-args.

## [Unreleased] - 2026-05-19

### Added — Flatpak packaging

The project can now be packaged and distributed as a Flatpak for Linux
systems. The following files were added under `packaging/flatpak/`:

- **`dev.kenya.quantframe.yml`** — Flatpak manifest.
- **`dev.kenya.quantframe.desktop`** — desktop launcher entry.
- **`dev.kenya.quantframe.metainfo.xml`** — AppStream metainfo (required for
  modern Flatpaks; `appstreamcli compose` runs as part of the build).

A new top-level `CHANGELOG.md` (this file) and a new "Run via Flatpak"
section in `README.md` were added.

### Manifest highlights

- **Runtime: `org.gnome.Platform // 49`** with `org.gnome.Sdk // 49`.
  - The GNOME runtime is required because it bundles `webkit2gtk-4.1`,
    which Tauri's webview layer (wry) links against. The plain
    `org.freedesktop.Platform` runtime does **not** ship WebKit2GTK and
    the build fails with `Package 'javascriptcoregtk-4.1' not found` if
    you try (this was the first failure mode encountered during this
    work — see "Build history" below).
  - GNOME 49 is based on freedesktop 25.08, so the SDK extensions are
    pulled at branch `25.08`.
- **SDK extensions:**
  - `org.freedesktop.Sdk.Extension.rust-stable // 25.08` — provides
    `cargo` / `rustc` at `/usr/lib/sdk/rust-stable/bin`.
  - `org.freedesktop.Sdk.Extension.node22 // 25.08` — provides `node`
    and `npm` at `/usr/lib/sdk/node22/bin`.
- **Build steps** (inside the sandbox):
  1. `npm install --prefix .pnpm-prefix -g pnpm@9` installs pnpm into a
     module-local prefix so we don't need to write to the read-only
     `/usr` tree.
  2. `pnpm install --no-frozen-lockfile` fetches JS dependencies.
  3. `pnpm exec tauri build --no-bundle` produces a **release** binary.
     `--no-bundle` is used because Flatpak is itself the distribution
     format — there's no point making Tauri also produce
     `.deb` / `.AppImage` artifacts inside the sandbox.
  4. The binary, icons (32/128/256/512 px), `.desktop` file, and
     `metainfo.xml` are installed under `/app/...`.
- **Network during build** is enabled
  (`build-options.build-args: --share=network`) so `pnpm` and `cargo`
  can fetch dependencies. This is fine for personal / local
  distribution but is **not** acceptable for a Flathub submission — that
  would require pre-vendoring all dependencies via
  `flatpak-node-generator` and a Cargo equivalent, which adds large
  generated files to the repo and was explicitly out of scope.
- **`finish-args` (runtime permissions):**
  - `--share=ipc`, `--share=network` — required for talking to
    `warframe.market` and the WebSocket feed.
  - `--socket=wayland`, `--socket=fallback-x11`, `--socket=pulseaudio` —
    display and audio.
  - `--device=dri` — GPU access for WebKit compositing.
  - `--filesystem=xdg-download`, `--filesystem=xdg-documents` — limited
    host file access for file dialogs.
  - `--talk-name=org.freedesktop.Notifications` — for the Tauri
    notification plugin.
  - `--talk-name=org.freedesktop.secrets` — Secret Service access for
    credential storage.
- Environment variables `WEBKIT_DISABLE_DMABUF_RENDERER=1` and
  `WEBKIT_DISABLE_COMPOSITING_MODE=1` are set defensively to work
  around known WebKitGTK rendering issues on Linux (notably with the
  proprietary NVIDIA driver) that can otherwise produce a blank window.

### Build & verification performed

1. Ran `flatpak-builder --user --force-clean --disable-rofiles-fuse
   flatpak-build packaging/flatpak/dev.kenya.quantframe.yml` from the
   repo root.
2. After fixing the runtime (see below), the build completed
   successfully; `appstreamcli compose` accepted the metainfo without
   warnings.
3. Installed the result with
   `flatpak-builder --user --install --force-clean ...`.
4. Smoke-tested `flatpak run --user dev.kenya.quantframe`:
   - Database migrations applied.
   - All `warframe.market` REST API calls succeeded.
   - Both WebSocket feeds (`ws.warframe.market` and `warframe.market`)
     connected.
   - Local item cache loaded (19,041 items, 1,338 price entries).
   - Tauri window opened and ran until the smoke-test timeout
     terminated it.
   - The single expected warning was
     `File not found: /home/ocko/.var/app/dev.kenya.quantframe/data/Warframe/EE.log`,
     which is the Warframe game's own log file — not a packaging
     issue, just a sandboxed app that does not (and should not) have
     access to the host Warframe installation by default.

### Build history (debugging notes for future maintainers)

- **First attempt** used `org.freedesktop.Platform // 24.08`. The Rust
  build failed at `javascriptcore-rs-sys` with
  `Package 'javascriptcoregtk-4.1' not found`. The freedesktop SDK does
  not bundle WebKit2GTK. Resolved by switching the runtime to GNOME.
- **Second attempt** used `org.gnome.Platform // 47`. Built and ran
  successfully, but `flatpak-builder` warned that GNOME 47 is
  end-of-life (October 15, 2025). Bumped to GNOME 49.
- **Third attempt** (`org.gnome.Platform // 49`, committed) built and
  ran successfully.

### Unchanged

- No Rust source, Tauri config (`tauri.conf.json`), `Cargo.toml`, or
  `package.json` was modified.
- The existing `pnpm tauri:build` script (which builds in `--debug`
  mode) is left as-is for normal local development. The Flatpak build
  intentionally calls `pnpm exec tauri build` directly to get a release
  binary.

### Added — single-file `.flatpak` bundle for GitHub release distribution

In addition to building & installing from the manifest, the project now
produces a single-file `.flatpak` bundle suitable for upload as a GitHub
release asset:

- Build & export to a local OSTree repo:

  ```bash
  flatpak-builder --user --force-clean --disable-rofiles-fuse \
    --repo=flatpak-build/repo \
    flatpak-build/builddir \
    packaging/flatpak/dev.kenya.quantframe.yml
  ```

- Pack the exported `dev.kenya.quantframe` ref into a portable bundle:

  ```bash
  flatpak build-bundle \
    --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
    flatpak-build/repo \
    flatpak-build/Quantframe-x86_64-1.6.20.flatpak \
    dev.kenya.quantframe master
  ```

- The `--runtime-repo` flag embeds a pointer to Flathub inside the
  bundle. When a user runs `flatpak install Quantframe-...flatpak`,
  Flatpak will offer to pull the GNOME 49 runtime from Flathub
  automatically if it isn't installed yet — the user does not need to
  add the remote manually first.

The resulting file (~13 MB) was verified by:

1. `flatpak uninstall --user dev.kenya.quantframe` (clear existing
   install).
2. `flatpak install --user --bundle
   flatpak-build/Quantframe-x86_64-1.6.20.flatpak` — install completed
   cleanly.
3. `flatpak run dev.kenya.quantframe` — app launched, DB migrated,
   warframe.market API + WebSocket connected, item cache loaded.

### How to build and run

See the new "Run via Flatpak" section in `README.md`.
