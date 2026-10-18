extends "res://tests/test_base.gd"

func run() -> void:
    var requested := "" if mode == "empty" else ("Sp\u00f6ut \u2713" if mode == "unicode" else "DuplicateSender")
    var long_name := mode.begins_with("long_")
    var expected_name := requested
    var receiver_name := requested
    var project_name := str(ProjectSettings.get_setting("application/config/name"))
    if long_name:
        requested = "A".repeat(300) if mode == "long_ascii" else "A".repeat(239) + "\u2713".repeat(30)
        expected_name = "A".repeat(240 if mode == "long_ascii" else 239)
        var direct: Object = ClassDB.instantiate(&"Spout")
        direct.call("set_sender_name", requested)
        check(str(direct.call("get_name")) == expected_name, "Direct sender name was not truncated at a UTF-8 boundary")
        direct = null
        receiver_name = requested
        if mode == "long_project":
            ProjectSettings.set_setting("application/config/name", requested)
            requested = ""
    var other: SubViewport
    if mode == "duplicate" or mode == "long_unicode":
        other = make_viewport(requested)
        await frames(4)
    var vp := make_viewport(requested)
    # The name is applied on tree entry; restore it before engine cache writes.
    if mode == "long_project":
        ProjectSettings.set_setting("application/config/name", project_name)
    await frames(2)
    var has_getter := vp.has_method("get_active_sender_name")
    var active := str(vp.call("get_active_sender_name")) if has_getter else ""
    for i in 60:
        await frames(1)
        if has_getter:
            check(str(vp.call("get_active_sender_name")) == active, "Active sender name changed")
    var log_text: String = logger.call("get_debug_log")
    var count := log_text.count("spoutSenderNames::CreateSender")
    var expected := 2 if other else 1
    print("[STABILITY] mode=%s CreateSender=%d expected=%d active=%s" % [mode, count, expected, active])
    check(count == expected, "Sender was recreated: %d CreateSender calls" % count)
    check(has_getter and not active.is_empty(), "Missing active sender name")
    check(str(vp.get("sender_name")) == requested, "Requested name changed during truncation")
    if long_name:
        check(active == expected_name + ("_1" if other else ""), "Long active sender name has wrong truncation/suffix")
        var receiver: Object = ClassDB.instantiate(&"Spout")
        # The duplicate's unsuffixed sender is still available for this request.
        receiver.call("set_receiver_name", receiver_name)
        var image := Image.new()
        var received := false
        for i in 10:
            received = bool(receiver.call("receive_image", image, 0x1908)) or received
            await frames(1)
        check(received and str(receiver.call("get_sender_name")) == expected_name, "Long receiver name did not connect to the truncated sender")
        receiver.call("release_receiver")
        receiver = null
    var listed := false
    for i in int(logger.call("get_sender_count")):
        listed = listed or str(logger.call("get_sender", i)) == active
    check(listed, "Active sender name did not round trip through enumeration")
    if mode == "unicode":
        check(active == requested, "UTF-8 name did not round trip")
    if mode == "empty":
        check(active == str(ProjectSettings.get_setting("application/config/name")), "Empty name did not use project name")
    check(int(vp.call("get_successful_frame_count")) >= 60, "Sender did not send frames")
    vp.free()
    if other:
        other.free()
    finish()
