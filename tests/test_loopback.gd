extends "res://tests/test_base.gd"

func run() -> void:
    var vp := make_viewport("LoopbackSender", mode == "opaque" or mode == "hdr_opaque", mode.begins_with("hdr"))
    var alpha := 0.5 if mode == "hdr_alpha" else 1.0
    (vp.get_child(0) as ColorRect).color.a = alpha
    var expected := Color(1, 0.5, 0, alpha)
    if mode == "hdr_alpha":
        # Transparent HDR readback has RGB premultiplied in linear space.
        expected = expected.srgb_to_linear()
        expected.r *= alpha
        expected.g *= alpha
        expected.b *= alpha
        expected = expected.linear_to_srgb()
    var texture := ClassDB.instantiate(&"SpoutTexture") as Texture2D
    texture.set("sender_name", "LoopbackSender")
    await frames(90)
    var image := texture.get_image()
    check(image != null and image.get_size() == Vector2i(64, 32), "Receiver has wrong dimensions")
    if image != null and image.get_size() == Vector2i(64, 32):
        var pixel := image.get_pixel(32, 16)
        print("[LOOPBACK] %s expected=%s actual=%s" % [mode, expected, pixel])
        check(absf(pixel.r - expected.r) <= 2.0 / 255 and absf(pixel.g - expected.g) <= 2.0 / 255 and absf(pixel.b - expected.b) <= 2.0 / 255 and absf(pixel.a - alpha) <= 2.0 / 255, "Loopback colour mismatch")
    texture = null
    vp.free()
    finish()
