extends "res://tests/test_base.gd"

func run() -> void:
    var vp := make_viewport("BoundsSender")
    var receiver: Object = ClassDB.instantiate(&"Spout")
    receiver.call("set_receiver_name", "BoundsSender")
    await frames(10)
    var image := Image.new() if mode == "empty" else Image.create_empty(1, 1, false, Image.FORMAT_RGBH if mode == "format" else Image.FORMAT_RGBA8)
    var received := false
    for i in 10:
        if receiver.call("receive_image", image, 0x1908):
            received = true
            check(image.get_size() == vp.size and image.get_format() == Image.FORMAT_RGBA8, "receive_image did not resize/convert destination")
        await frames(1)
    check(received, "No initial frame received")
    check(bool(receiver.call("is_updated")), "receive_image consumed the connection update")
    check(not bool(receiver.call("is_updated")), "Connection update did not clear after reading")
    vp.size = Vector2i(128, 64)
    await frames(5)
    received = false
    for i in 10:
        if receiver.call("receive_image", image, 0x1908):
            received = true
            check(image.get_size() == vp.size, "Resized sender did not resize destination")
        await frames(1)
    check(received, "No resized frame received")
    check(bool(receiver.call("is_updated")), "receive_image consumed the resize update")
    check(not bool(receiver.call("is_updated")), "Resize update did not clear after reading")
    receiver.call("release_receiver")
    receiver = null
    vp.free()
    finish()
