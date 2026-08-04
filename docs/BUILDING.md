# Rebuilding the native extension

## Pinned source

- Spout-GD: `867b32df99738554a41117f947844e648ac6bef9`
- Spout2: `5c05489d2fc5fa4dd689a2a13ac65c3c4e976ae2`
- godot-cpp: `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77`
- Redot patch: `patches/spout-gd-redot-26.2.patch`

## Prerequisites

- Windows x64
- Git with submodule support
- Python 3 and SCons
- CMake
- A Visual Studio C++ Build Tools installation capable of building Godot/Redot-compatible x64 libraries

## Clone the patched source

```powershell
git clone --recursive https://github.com/dominicbytes/spout-gd.git spout-gd-source
Set-Location spout-gd-source
git checkout v0.1.0-alpha.1
git submodule update --init --recursive
```

The tag already contains the Redot source changes and pins the Spout2 and godot-cpp commits listed above. `patches/spout-gd-redot-26.2.patch` is retained only as an auditable diff against upstream commit `867b32d`.

Build Spout2 as described by upstream, then build both GDExtension targets:

```powershell
scons platform=windows target=template_debug arch=x86_64
scons platform=windows target=template_release arch=x86_64
```

Stage these outputs under `addons/spout-gd`:

- `spout_gd.gdextension`
- `out/spout_gd.windows.template_debug.dll`
- `out/spout_gd.windows.template_release.dll`
- `Spout2/Binaries/x64/SpoutLibrary.dll`

Run the headless smoke test and a bounded D3D12 demo before packaging. The installed Redot build is authoritative; successful compilation against upstream Godot headers alone is not sufficient validation.

Create the installable archive and checksum from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/package-release.ps1 -Version 0.1.0-alpha.1
```
