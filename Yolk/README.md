# Yolk Build Process

This document explains the Docker build and runtime design for the S&Box egg image.

## Files

- `DockerFile`: multi-stage build definition.
- `entrypoint.sh`: runtime orchestration (seed, launch).

## Build Overview

The image uses two stages:

1. Builder stage (`debian:trixie-slim`)
- Installs Wine, winetricks, and build dependencies.
- Creates and provisions a Wine prefix.
- Installs Windows .NET runtime into that prefix.
- Performs a build-time S&Box content bake using SteamCMD into `/work/server`.
- Cleans up temporary build SteamCMD content after bake.

2. Runtime stage (`alpine:edge`)
- Installs runtime packages (Wine, bash, wget, etc.).
- Copies baked Wine prefix and baked server template only.

This avoids runtime compatibility issues caused by carrying a builder-baked SteamCMD into Alpine runtime.

## Build Command

# Yolk — Build & Runtime

This document covers the Docker build and runtime design for the S&Box egg image.

## Files

- `Dockerfile` — Multi-stage build definition.
- `entrypoint.sh` — Runtime orchestration: seed, update, launch.

## Build Overview

The image uses two stages:

**Stage 1 — Builder** (`debian:trixie-slim`)
- Installs Wine, winetricks, and build dependencies.
- Creates and provisions a 64-bit Wine prefix.
- Installs the Windows .NET runtime into the prefix via Wine.
- Bakes the S&Box Windows server depot (app `1892930`) via SteamCMD into `/work/server`.
- Cleans up the build-time SteamCMD tooling after bake.

**Stage 2 — Runtime** (`steamcmd/steamcmd:alpine`)
- Official Valve SteamCMD Alpine image — provides a working glibc bootstrap and `/usr/bin/steamcmd`.
- Wine and minimal runtime packages are installed on top via `apk`.
- Baked Wine prefix copied to `/opt/sbox-wine-prefix`.
- Baked server template copied to `/opt/sbox-server-template`.

On first boot, `entrypoint.sh` seeds both into `/home/container` (the Pterodactyl volume), then runs SteamCMD to update before launching.

## Build Arguments

| Argument | Default | Description |
|---|---|---|
| `BAKE_WIN_DOTNET_VERSION` | `10.0.0` | Windows .NET runtime version to install at build time |
| `BAKE_SBOX_APP_ID` | `1892930` | Steam App ID for the S&Box server depot |
| `BAKE_WINETRICKS_VERBS` | `win10 vcrun2022` | Winetricks verbs applied to the baked Wine prefix |

## Build Command

Run from repository root:

```bash
docker build --platform linux/amd64 -f Yolk/Dockerfile -t ghcr.io/hyberhost/gameforge-sbox-egg:latest .
```

With custom build args:

```bash
docker build --platform linux/amd64 \
  -f Yolk/Dockerfile \
  -t ghcr.io/hyberhost/gameforge-sbox-egg:latest \
  --build-arg BAKE_WIN_DOTNET_VERSION=10.0.0 \
  --build-arg BAKE_SBOX_APP_ID=1892930 \
  .
```

## Runtime Notes

- Startup entrypoint command: `start-sbox`.
- SteamCMD is provided by the `steamcmd/steamcmd:alpine` base image. No installer runs inside the container volume.
- Library paths are set explicitly to avoid 32/64-bit `libgcc_s` conflicts between SteamCMD and Wine.
- Logs are written to `/home/container/logs/`.

## Local Validation

```bash
# Shell syntax check
bash -n Yolk/entrypoint.sh

# Smoke test against a fresh volume
docker run --rm -it -v sbox-test:/home/container ghcr.io/hyberhost/gameforge-sbox-egg:latest start-sbox
```


## Linux-native experimental build

Build the native-linux variant:

```bash
docker build --platform linux/amd64 -f Yolk/Dockerfile.linux-native -t ghcr.io/hyberhost/gameforge-sbox-egg:linux-native .
```

Use `sandbox-pterodactyl-linux-native.json` with this image tag. The container updates with SteamCMD platform `linux` and executes `sbox-server` directly (no Wine), using an Alpine SteamCMD base image.

