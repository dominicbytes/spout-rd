# Third-party components

## Spout-GD

- Project: <https://github.com/you-win/spout-gd>
- Package: `spout-gd.windows.x86_64.zip`, prerelease tag `latest`
- Retrieved: 2026-07-23
- Package SHA-256: `a9ffdfb46343c88eeeda6fac8d78ca7f8874bbf99e8cecf80c18245efd486327`
- Declared bindings target: Godot 4.5
- License: MPL-2.0

The packaged addon contains the Spout-GD GDExtension binaries and `SpoutLibrary.dll`. Spout-GD wraps the Spout2 SDK; Spout2 is distributed under the BSD 2-Clause license. This Redot package retains the upstream addon filenames and directory structure.

The checked-in DLLs were rebuilt from Spout-GD commit `867b32df99738554a41117f947844e648ac6bef9` with pinned submodules Spout2 `5c05489d2fc5fa4dd689a2a13ac65c3c4e976ae2` and godot-cpp `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77`. The Redot-specific source correction is retained in `patches/spout-gd-redot-26.2.patch`.

Rebuilt binary SHA-256 values:

- `spout_gd.windows.template_debug.dll`: `03999533ff66877804dd64086048d5d4efb99d67cb1575ca2d3c182d8ee3ac7b`
- `spout_gd.windows.template_release.dll`: `ef3d8e92243afbc04d110e62f1ba1ee94bedf75005566b2c39c05143df7fab0d`
- `SpoutLibrary.dll`: `347b9fbc6f6b29d99d662fec8c3f367021fd0b863e44ba5989eb174fcce21c11`

Exact upstream license files are retained beside the binaries as `LICENSE.spout-gd` and `LICENSE.spout2`.
