# QuantFrame

Inspired by [Akmayer's Warframe-Algo-Trader](https://github.com/akmayer/Warframe-Algo-Trader), this is a re-implementation using tauri. Tauri allows for easy distribution to windows & linux without technical knowledge.

## Features

- Distribute as windows
  - Install size: 35MB
  - Idle resource consumption: 60MB, extremely small cpu footprint (on my rig, 0-0.1%)
  - Update distribution
- Save data in sqllite db located at `C:\Users\*\AppData\Local\dev.kenya.quantframe\quantframe.sqlite`
- Logs and setings wil be save at `C:\Users\*\AppData\Local\dev.kenya.quantframe`
  - easily inspectible with db tools like https://beekeeperstudio.io
- Api client to communicate with wf.market
- Easy debugging / developer experience via edge dev tools

## Screenshots

![Login Screen](./docs/assets/login.png)

![Main Screen](./docs/assets/main-screen.png)
https://github.com/Kenya-DK/quantframe-react
![Listing an item](./docs/assets/listing.png)

## Installation

### Download installer

You can download the latest release from [here](https://github.com/Kenya-DK/quantframe-react/releases)

### OR Build it from source

If you prefer to build it locally for whatever reason, heres what you need:

#### Step 1. Install Pre-Requisites

Follow the [Tauri Pre-requisites](https://tauri.app/v1/guides/getting-started/prerequisites) guide to get necessary dependencies.

> If you're using **Windows**, you CANNOT use WSL for this project. You MUST install pre-requisites on windows, not WSL.

You will also need to make sure you've got Nodejs installed.

#### Step 2. Download code

I would strongly recommend installing [git](https://git-scm.com/) or [Github Desktop](https://desktop.github.com/) and use those to download the project source code from github. The reason is this will allow you to download new versions of the code much easier than clicking "download zip" every time.

##### Step 2.1. Delete

delete the `pubkey` filed in `tauri/src-tauri/tauri.conf.json`.

##### Step 2.2 Copy the 'PRODUCTION_URL' to 'DEVELOPMENT_URL' field in `tauri/src-tauri/qf_api/src/client.rs`.

#### Step 3. Build the project

Open a terminal at the project root and run:

<details>
<summary>
<i>How do I do this on windows?</i>
</summary>

On windows, this is easily done by click the path:

![path](./docs/assets/open-terminal-1.png)

Then type in `powershell` and hit enter

![ps](./docs/assets/open-terminal-2.png)

</details>

```bash
pnpm i # Install nodejs deps
pnpm run tauri build
```

> For developers, you can also use yarn or pnpm if you prefer. (pnpm is the fastest package manager)

## Run via Flatpak (Linux)

Quantframe ships a Flatpak manifest under `packaging/flatpak/` so it can be
built and installed as a sandboxed Linux desktop app.

### Prerequisites

Install `flatpak` and `flatpak-builder` using your distribution's package
manager, then make sure the Flathub remote is configured and the required
runtime and SDK extensions are installed:

```bash
# One-time setup: add Flathub if you don't have it yet
flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo

# Runtime, SDK, and the toolchain extensions referenced by the manifest
flatpak install --user flathub \
  org.gnome.Platform//49 \
  org.gnome.Sdk//49 \
  org.freedesktop.Sdk.Extension.rust-stable//25.08 \
  org.freedesktop.Sdk.Extension.node22//25.08
```

> The GNOME runtime is required because it bundles `webkit2gtk-4.1`, which
> Tauri's webview layer depends on. The plain `org.freedesktop.Platform`
> runtime does **not** include WebKit2GTK.

### Build

From the repository root:

```bash
flatpak-builder --user --force-clean --install \
  flatpak-build packaging/flatpak/dev.kenya.quantframe.yml
```

What this does:

- `flatpak-build/` is a scratch directory used while assembling the app.
- `--install` installs the resulting Flatpak into your user-scope
  installation when the build succeeds.
- `.flatpak-builder/` is created alongside the manifest and caches sources
  between builds — keep it around to speed up rebuilds.

The first build downloads the full Tauri Rust dependency graph and the
Node modules and can take 15–30 minutes on a typical machine. Subsequent
builds re-use the cache and are much faster.

### Run

```bash
flatpak run dev.kenya.quantframe
```

Or launch **Quantframe** from your desktop application menu.

### Uninstall

```bash
flatpak uninstall --user dev.kenya.quantframe
```

### Notes

- The build allows network access inside the sandbox so `pnpm` and
  `cargo` can fetch dependencies. This is fine for personal use and
  local distribution, but a Flathub submission would require fully
  pre-vendored sources.
- The bundled binary is a **release** build, not the `--debug` build
  produced by `pnpm run tauri:build`.
- On NVIDIA proprietary drivers, the manifest sets
  `WEBKIT_DISABLE_DMABUF_RENDERER=1` and
  `WEBKIT_DISABLE_COMPOSITING_MODE=1` to work around known WebKitGTK
  rendering issues that can cause a blank window.

## About the project

This project uses:

- [Tauri](https://tauri.app): like electron but using a [Rust](https://www.rust-lang.org/) backend and doesn't use Chromium, leading to better performance.
- [React](https://react.dev/): For the frontend.
- [Mantine](https://mantine.dev/): use for the UI.
- [Sqlite](https://www.sqlite.org/index.html): For the database.

## 💰 Support My work

<p><a href="https://www.buymeacoffee.com/kenyadk"> <img align="left" src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" height="45" width="210" alt="kenyadk" /></a></p>
<p><a href="https://patreon.com/kenya_dk"> <img align="left" src="https://img.shields.io/badge/Patreon-F96854?style=for-the-badge&logo=patreon&logoColor=white" height="45" width="210" alt="kenya_dk" /></a></p>
