# Redot Spout GD runtime

This folder is the installable Windows x64 GDExtension for Redot 26.2.

Copy the entire `addons/spout-gd` folder into a Redot project, restart the editor, and confirm that `ClassDB.class_exists(&"SpoutViewport")` returns `true`. This is a runtime GDExtension; it does not use `plugin.cfg` or the editor's Plugins checkbox.

The tested Forward+/D3D12 sender uses synchronous GPU-to-CPU image readback. Keep `prefer_direct_texture` disabled. Direct OpenGL sharing is experimental and guarded off by default because it crashes the tested Redot/NVIDIA configuration.

Project documentation, source code, build instructions, and releases: <https://github.com/dominicbytes/spout-gd>

Spout-GD is MPL-2.0 licensed. Spout2 is BSD 2-Clause licensed. The exact notices are retained in this folder.
