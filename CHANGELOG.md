# Changelog

## 0.1.0-alpha.1 - 2026-07-23

- Rebuilt upstream Spout-GD for Redot 26.2 testing.
- Corrected direct-path lookup to use the viewport's rendered texture RID.
- Added a safe default that prevents the known GL/DX interop crash.
- Enabled Spout CPU mode for the D3D12 image/readback path.
- Added sender health, successful-frame count, transfer-path, and debug-log diagnostics.
- Added a typed-GDScript demo, headless smoke test, build provenance, licenses, and release packaging.
- Verified 1920x1080 RGBA reception at 60 FPS in a workspace-contained portable OBS copy, including live animation and reconnect recovery.
