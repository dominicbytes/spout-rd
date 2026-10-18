# Changelog

## 0.2.0-alpha.1 - Unreleased

- Verified Redot 26.3 compatibility without an ABI change; `compatibility_minimum` stays 4.5.
- Bounds-checked image transfers and kept senders stable during name resolution and sender churn.
- `Spout.receive_image()` now resizes the destination to the sender size and returns RGBA8 without mipmaps instead of writing into the caller's buffer as-is.
- Corrected HDR 2D colour conversion and added an explicit GL Compatibility warning.
- Disconnected and released senders on tree exit, guarded render-thread callbacks, and avoided editor-import receiver side effects.
- Package only `addons/spout-gd/` with forward-slash ZIP paths and bundled notices.
- Upload CI-built DLLs with SHA256 sums and add advisory Redot 26.3 headless D3D12/Vulkan regression tests.

## 0.1.0-alpha.1 - 2026-07-23

- Rebuilt upstream Spout-GD for Redot 26.2 testing.
- Corrected direct-path lookup to use the viewport's rendered texture RID.
- Added a safe default that prevents the known GL/DX interop crash.
- Enabled Spout CPU mode for the D3D12 image/readback path.
- Added sender health, successful-frame count, transfer-path, and debug-log diagnostics.
- Added a typed-GDScript demo, headless smoke test, build provenance, licenses, and release packaging.
- Verified 1920x1080 RGBA reception at 60 FPS in a workspace-contained portable OBS copy, including live animation and reconnect recovery.
