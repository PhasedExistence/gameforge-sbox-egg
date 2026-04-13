# Linux-native s&box egg notes

This branch is a reference starting point for migrating from the Wine-based egg to a native Linux runtime.

## Upstream references

- Facepunch public repo: https://github.com/Facepunch/sbox-public
- DrakeFruit fix PR: https://github.com/Facepunch/sbox-public/pull/10377
- DrakeFruit linux docker reference: https://github.com/DrakeFruit/sbox-public-linux-docker

## What this branch changes

1. Adds an experimental Linux-native runtime Dockerfile (`Yolk/Dockerfile.linux-native`).
2. Adds a Linux-native startup script (`Yolk/entrypoint-linux.sh`) that:
   - forces SteamCMD platform to `linux`,
   - updates app `1892930`,
   - launches native `sbox-server` instead of Wine.
3. Adds a matching Pterodactyl egg export (`sandbox-pterodactyl-linux-native.json`).

## Caveats

- This does **not** guarantee a successful Linux-native dedicated server boot by itself.
- Successful operation still depends on upstream game/runtime fixes and depots being published.
- Keep the existing Wine egg as the production fallback while validating Linux-native behavior.

## Pelican egg comparison takeaways

The community Pelican native egg highlighted a few runtime details that are now mirrored in this branch:

- include `game/bin/linuxsteamrt64` in `LD_LIBRARY_PATH` when present,
- expose `DOTNET_ROOT` and append it to `PATH`,
- normalize carriage-return log output (`tr '\r' '\n'`),
- recognize `Load Complete` as an additional startup done signal.
