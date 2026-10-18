extends "res://tests/test_base.gd"

func run() -> void:
    check(ClassDB.class_get_integer_constant(&"Spout", &"FORMAT_RGB") == 0x1907, "FORMAT_RGB is not bound")
    for level: String in ["SILENT", "VERBOSE", "NOTICE", "WARNING", "ERROR", "FATAL", "NONE"]:
        check(ClassDB.class_has_integer_constant(&"Spout", "SPOUT_LOG_" + level), "Missing Spout log level " + level)
    check(ClassDB.class_get_integer_constant(&"Spout", &"FORMAT_BGRA") == ClassDB.class_get_integer_constant(&"Spout", &"FORMAT_BGRA_EXT"), "BGRA alias changed")
    check(str(logger.call("get_sender", 0xFFFFFFFF)).is_empty(), "Invalid sender index must return an empty name")
    check(str(logger.call("get_sender", int(logger.call("get_sender_count")) + 1024)).is_empty(), "Failed Spout enumeration returned a name")
    var image := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
    # These calls intentionally emit native validation errors. Silence printing only
    # during the synchronous invalid calls, and assert their return values afterwards.
    var prior_print_errors := Engine.print_error_messages
    Engine.print_error_messages = false
    var rejected: Array[bool] = [
        not bool(logger.call("send_image", null, 1, 1)),
        not bool(logger.call("send_image", Image.new(), 1, 1)),
        not bool(logger.call("send_image", image, 64, 32)),
        not bool(logger.call("send_image", image, 1, 1, 0)),
        not bool(logger.call("send_image", image, 0xFFFFFFFF, 0xFFFFFFFF)),
        not bool(logger.call("send_texture", 0, 0x0DE1, 1, 1)),
        not bool(logger.call("send_fbo", 1, 0, 1)),
        not bool(logger.call("send_fbo", 1, 0xFFFFFFFF, 0xFFFFFFFF)),
        not bool(logger.call("receive_image", null, 0x1908)),
    ]
    Engine.print_error_messages = prior_print_errors
    for accepted: bool in rejected:
        check(accepted, "Invalid send/receive input was accepted")
    # Keep error printing enabled: the runner rejects any wrapper validation error.
    # Without a GL context the SDK may return false for the default framebuffer.
    for size: Vector2i in [Vector2i(1, 1), Vector2i.ZERO, Vector2i(0, 1), Vector2i(1, 0)]:
        check(typeof(logger.call("send_fbo", 0, size.x, size.y)) == TYPE_BOOL, "Default framebuffer call did not return a bool")
    logger.call("disable_debug_log")
    var before := FileAccess.get_file_as_string("res://spout-test.log")
    var temporary: Object = ClassDB.instantiate(&"Spout")
    temporary.call("release_sender")
    temporary = null
    check(FileAccess.get_file_as_string("res://spout-test.log") == before, "disable_debug_log did not stop logging")
    finish()
