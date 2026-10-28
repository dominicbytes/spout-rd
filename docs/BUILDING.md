# Rebuilding the native extension

## Pinned source

- Spout-GD: `867b32df99738554a41117f947844e648ac6bef9`
- Spout2: `5c05489d2fc5fa4dd689a2a13ac65c3c4e976ae2`
- redot-cpp fork: `9e7161bd7a3572a36ffa93109e73169861e9f834` (in the `godot-cpp` directory)
- Historical Redot 26.2 patch: `patches/spout-gd-redot-26.2.patch`

## Prerequisites

- Windows x64
- Git with submodule support
- Python 3 and SCons
- CMake
- A Visual Studio C++ Build Tools installation capable of building Godot/Redot-compatible x64 libraries

## Clone the patched source

```powershell
git clone --recursive https://github.com/dominicbytes/spout-rd.git spout-rd-source
Set-Location spout-rd-source
git submodule update --init --recursive
```

The source includes the Redot changes and pins the Spout2 and redot-cpp commits listed above. `patches/spout-gd-redot-26.2.patch` is retained only as an auditable diff against upstream commit `867b32d`.

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

The current hardening target is Redot 26.3-stable. The fork generates a 4.5.2 compatibility version; `compatibility_minimum` remains 4.5. Checked-in DLLs predate the binding switch and must be rebuilt for a release.

Set `REDOT_BIN` to the Redot 26.3 console editor executable, then run `pwsh tests/run_tests.ps1 -Driver d3d12` and `pwsh tests/run_tests.ps1 -Driver vulkan`, plus a bounded D3D12 demo before packaging. The installed Redot build is authoritative; successful compilation against upstream Godot headers alone is not sufficient validation.

Create the installable archive and checksum from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/package-release.ps1 -Version 0.2.0-alpha.1
```

The archive contains only `addons/spout-gd/`, with README, LICENSE and THIRD_PARTY.md inside that folder. `dist/SHA256SUMS.txt` hashes the ZIP.

CI uploads each freshly built target DLL and SpoutLibrary.dll with SHA256SUMS.txt. The advisory Windows headless test matrix downloads and verifies those artifacts before staging them over the checked-in addon binaries. It downloads the official `redot-26.3-stable` Windows editor and checks its published SHA512 (also pinned in the workflow). D3D12 and Vulkan runs are marked `continue-on-error`: hosted runners have no guaranteed GPU/Spout support, so these results do not replace local GPU validation.
