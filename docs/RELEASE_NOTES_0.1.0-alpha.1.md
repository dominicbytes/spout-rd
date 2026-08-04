# Redot Spout GD 0.1.0-alpha.1

First public Redot-focused prerelease of Spout-GD for Windows x64.

## Included

- Patched and rebuildable C++ GDExtension source based on `you-win/spout-gd` commit `867b32d`.
- Debug and release Windows x64 GDExtension DLLs.
- Pinned Spout2 and godot-cpp submodules.
- `SpoutViewport` sender diagnostics and a safe direct-texture opt-in.
- A Redot 26.2 demo project, typed-GDScript smoke test, API notes, build provenance, and third-party notices.
- Installable ZIP that extracts directly into a Redot project root.

## Verified configuration

- Redot `26.2.stable.official.4f5b14aba`
- Windows x64
- Forward+/Direct3D 12
- NVIDIA GeForce RTX 4080 SUPER
- Portable OBS 32.1.2 with the Spout2 OBS source
- 1920x1080 RGBA at 60 FPS, including live animation, alpha, and sender reconnect

## Known limitations

- The reliable Direct3D 12 path performs synchronous GPU-to-CPU readback and is not zero-copy.
- End-to-end latency still needs comparison against OBS Game/Window Capture under a representative stream load.
- Direct OpenGL texture sharing is experimental and disabled by default due to a tested GL/DX interop crash.
- Receiver support comes from upstream but is not covered by this fork's integration tests yet.
- Spout transports video only; capture Redot application audio separately in OBS.

## Install

1. Download `redot-spout-gd-0.1.0-alpha.1-windows-x86_64.zip` and `SHA256SUMS.txt`.
2. Verify the archive checksum.
3. Extract the ZIP into the root of a Redot project.
4. Restart Redot and confirm `res://addons/spout-gd/spout_gd.gdextension` exists.

This release is marked as a prerelease because the transfer path is functional but not yet latency-optimized.
