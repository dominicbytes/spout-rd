# Runtime API notes

The extension registers three native classes: `Spout`, `SpoutTexture`, and `SpoutViewport`.

## SpoutViewport

`SpoutViewport` extends `SubViewport` and is the recommended output surface.

| Member | Type | Purpose |
|---|---|---|
| `sender_name` | `String` property | Spout sender name visible to receivers. |
| `prefer_direct_texture` | `bool` property | Experimental OpenGL direct-texture opt-in. Keep `false` on the tested Redot 26.2 configuration. |
| `is_sending()` | `bool` | Reports whether the most recent native send succeeded. |
| `get_successful_frame_count()` | `int` | Number of successful sends since this viewport started. |
| `is_using_direct_texture()` | `bool` | Reports whether the experimental direct path is active. |

Use normal `SubViewport` properties for resolution, transparency, update mode, and child content.

## Spout

`Spout` exposes the lower-level upstream send, receive, sender-list, and metadata methods. The Redot patch adds:

| Method | Purpose |
|---|---|
| `set_cpu_mode(enabled: bool)` | Selects Spout's CPU staging mode for the image/readback path. |
| `enable_debug_log(path: String)` | Enables Spout's native debug log at an absolute path. |
| `get_debug_log()` | Returns the active debug-log path/status from Spout. |

The upstream API also includes `send_image`, sender enumeration, receiver selection, and frame metadata methods. See the retained upstream README in `addons/spout-gd/README.md`.

## SpoutTexture

`SpoutTexture` is the upstream receiving texture resource. Its key properties are `sender_name` and `update_in_editor`. Receiver behavior was not the focus of the Redot output validation, so treat it as available but not yet covered by this package's integration tests.

## Renderer behavior

- Forward+/D3D12: tested output path; each frame is read back to an `Image` and sent through Spout CPU mode.
- GL Compatibility: safe default does not send. Setting `prefer_direct_texture = true` opts into a diagnostic path that currently crashes inside Spout GL/DX interop on the tested system.
