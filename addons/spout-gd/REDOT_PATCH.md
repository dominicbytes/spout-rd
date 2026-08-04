# Redot 26.2 compatibility patch

The upstream prerelease registered in Redot 26.2, but its OpenGL direct-send path called `RenderingServer.texture_get_native_handle()` with the `SpoutViewport` RID. Redot requires the rendered texture RID, so the unmodified bridge emitted `Parameter "texture" is null` every frame and did not publish a usable texture.

This build defaults to the existing image/readback path under RenderingDevice renderers and explicitly enables Spout CPU mode before the first frame. Under GL Compatibility, the safe default does not call Spout because its GL/DX compatibility probe terminates this Redot/driver combination. Direct OpenGL texture sharing remains an explicit `prefer_direct_texture` diagnostic opt-in.

For the experimental direct path, the addon asks `RenderingServer.viewport_get_texture(get_viewport_rid())` for the actual render-target texture, validates that RID and its native handle, and only then calls Spout2. `ViewportTexture.get_rid()` is not used because it represents a proxy resource rather than the underlying render target in this Redot build.

The patch also exposes read-only send health (`is_sending()` and `get_successful_frame_count()`) plus opt-in Spout debug logging. These diagnostics let the GDScript host verify that the sender is actually publishing instead of assuming success from class registration.

The exact source change is in `../../patches/spout-gd-redot-26.2.patch`.
