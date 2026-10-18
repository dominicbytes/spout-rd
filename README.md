# Redot Spout GD

Windows x64 Spout2 input/output bindings prepared and tested for Redot 26.3. This package is a Redot-focused rebuild of [you-win/spout-gd](https://github.com/you-win/spout-gd), with a narrow compatibility and diagnostics patch for reliable `SpoutViewport` output.

Version: `0.2.0-alpha.1` (Unreleased)

This fork preserves the upstream history and contains the patched C++ source, pinned submodules, prebuilt Windows binaries, demo project, smoke test, build provenance, and release packaging. It is based on upstream commit [`867b32d`](https://github.com/you-win/spout-gd/commit/867b32df99738554a41117f947844e648ac6bef9).

The previous published installable ZIP is available from the [`v0.1.0-alpha.1` prerelease](https://github.com/dominicbytes/spout-rd/releases/tag/v0.1.0-alpha.1).

## Current status

- Tested with Redot `26.3.stable.official.85e520394` on Windows x64.
- No ABI change is needed for 26.3; `compatibility_minimum = 4.5` and the godot-cpp 4.5 pin remain unchanged.
- Forward+/D3D12 output works through synchronous GPU-to-CPU image readback.
- Verified in a local portable OBS 32.1.2 copy at 1920x1080 RGBA and 60 FPS using the Spout2 OBS plugin.
- Live animation, alpha, same-GPU operation, and sender reconnect were verified.
- Direct OpenGL texture sharing is experimental and disabled by default because Spout's GL/DX interop terminates the tested Redot/NVIDIA configuration.
- Spout carries video only. Capture application audio separately in OBS.

This is an alpha package. The readback path is functional but is not zero-copy, and end-to-end latency still needs comparison against OBS Game/Window Capture under representative load.

## Install

1. Download the Windows x64 release ZIP.
2. Extract it into the root of a Redot project.
3. Confirm this file exists: `res://addons/spout-gd/spout_gd.gdextension`.
4. Restart the Redot editor so it imports and loads the GDExtension.
5. Confirm `ClassDB.class_exists(&"SpoutViewport")` from GDScript.

This is a runtime GDExtension, not an `EditorPlugin`; there is no `plugin.cfg` checkbox to enable. Redot discovers the `.gdextension` descriptor automatically.

## Minimal sender

```gdscript
extends Node

var program: SubViewport


func _ready() -> void:
    assert(ClassDB.class_exists(&"SpoutViewport"))
    program = ClassDB.instantiate(&"SpoutViewport") as SubViewport
    program.name = "ProgramOutput"
    program.size = Vector2i(1920, 1080)
    program.transparent_bg = true
    program.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    program.set("sender_name", "MyRedotProgram")
    add_child(program)

    # Add the 2D/3D content to publish as children of program.
```

For the tested path, use Forward+ with the D3D12 rendering driver and leave `prefer_direct_texture` disabled.

## Demo and validation

The repository checkout includes a demo project and smoke test. Open its root as a Redot project and run it. The demo publishes `RedotSpoutDemo`, displays the same animated RGBA viewport locally, and writes `user://redot_spout_demo_report.json`.

Headless bridge smoke check:

```powershell
pwsh tests/run_tests.ps1 -Driver d3d12
pwsh tests/run_tests.ps1 -Driver vulkan
```

The install ZIP contains only `addons/spout-gd/`, including its README and license notices. It intentionally omits `project.godot`, `demo`, and `tests` so extracting it cannot replace a target project's settings or add sample content. Those files remain available in the repository checkout.

The repository also retains the native source under `src/`. The tested DLLs in `addons/spout-gd` are checked in so users do not need a C++ toolchain. Contributors can reproduce them using [docs/BUILDING.md](docs/BUILDING.md).

See [docs/API.md](docs/API.md), [docs/BUILDING.md](docs/BUILDING.md), [THIRD_PARTY.md](THIRD_PARTY.md), and [CHANGELOG.md](CHANGELOG.md).

## License and attribution

Spout-GD and this derivative patch are distributed under MPL-2.0. Spout2 is distributed under the BSD 2-Clause license. Exact license texts are retained under `addons/spout-gd`, with pinned revisions and binary hashes in [THIRD_PARTY.md](THIRD_PARTY.md).

## Notes

I vibe coded this in GPT Sol 5.6. Use at your own risk.

## About Dominic Bytes

Greetings! I am Dominic Bytes, the synth walker. I hail from the distant future. Where brains occupy robot bodies, time travel is a trip to the corner store, and the neon glow of our attire is powered by the light of our souls. Join me on a 1.21 gigawatt powered journey of chill vibes with gaming, anime, movies, and more!

- [Website](https://dominicbytes.carrd.co/)
- [X](https://x.com/DominicBytes)
- [Twitch](https://www.twitch.tv/dominicbytes)
- [YouTube](http://www.youtube.com/@DominicBytes)
- [Kick](https://kick.com/dominicbytes)
