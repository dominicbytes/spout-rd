extends "res://tests/test_base.gd"

func run() -> void:
    var sender: Object = ClassDB.instantiate(&"Spout")
    sender.call("set_cpu_mode", true)
    sender.call("set_sender_name", "InvertSender")
    var receiver: Object = ClassDB.instantiate(&"Spout")
    receiver.call("set_receiver_name", "InvertSender")
    # Vertical red gradient: black at the top, red at the bottom.
    var source := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
    for y in 16:
        for x in 16:
            source.set_pixel(x, y, Color(float(y) / 15, 0, 0, 1))
    var result := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
    var received := false
    for i in 30:
        sender.call("send_image", source, 16, 16)
        received = bool(receiver.call("receive_image", result, 0x1908)) or received
        receiver.call("is_updated")
        await frames(1)
    check(received, "Gradient was not received")
    var top := result.get_pixel(8, 0).r
    var bottom := result.get_pixel(8, 15).r
    print("[INVERT] default top=%f bottom=%f inverted=%s" % [top, bottom, top > bottom])
    # Lock in the existing GDScript orientation; match the C++ default to it.
    check(top >= 253.0 / 255 and bottom <= 2.0 / 255, "Default send_image orientation changed")
    receiver.call("release_receiver")
    sender.call("release_sender")
    receiver = null
    sender = null
    finish()
