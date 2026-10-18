extends "res://tests/test_base.gd"

func run() -> void:
    var vp := make_viewport("BytesSender")
    var receiver: Object = ClassDB.instantiate(&"Spout")
    receiver.call("set_receiver_name", "BytesSender")
    await frames(10)
    var data := PackedByteArray()
    for i in 10:
        data = receiver.call("receive_bytes")
        await frames(1)
    check(data.size() == 64 * 32 * 4, "receive_bytes returned wrong size")
    if data.size() == 64 * 32 * 4:
        check(data[0] == 255 and absi(data[1] - 128) <= 2 and data[2] == 0 and data[3] == 255, "receive_bytes pixels are wrong")
        var saved := data.duplicate()
        var rect := vp.get_child(0) as ColorRect
        rect.color = Color.BLUE
        await frames(5)
        var next := PackedByteArray()
        for i in 5:
            next = receiver.call("receive_bytes")
            await frames(1)
        check(next.size() == data.size() and next[2] == 255, "New frame was not received")
        check(data == saved, "Receiving another frame mutated a previously returned byte array")
        var small := PackedByteArray([17])
        check(not bool(receiver.call("receive_buffer", small, 0x1908)), "Undersized legacy buffer accepted")
        check(small == PackedByteArray([17]), "Legacy buffer mutated caller data")
        var large := PackedByteArray()
        large.resize(data.size())
        large.fill(17)
        check(bool(receiver.call("receive_buffer", large, 0x1908)), "Sized legacy buffer failed")
        check(large[0] == 17 and large[2] == 17, "Legacy buffer violated copy-on-write")
    receiver.call("release_receiver")
    receiver = null
    vp.free()
    finish()
