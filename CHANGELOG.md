# Changelog

All notable packaging and distribution changes are documented in this file.

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

### How to build and run

See the new "Run via Flatpak" section in `README.md`.
