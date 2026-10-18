extends "res://tests/test_base.gd"

func registered(sender: String) -> bool:
    for i in int(logger.call("get_sender_count")):
        if str(logger.call("get_sender", i)) == sender:
            return true
    return false

func run() -> void:
    var before := RenderingServer.get_signal_connection_list("frame_post_draw").size()
    var vp := make_viewport("LifecycleSender")
    await frames(10)
    check(registered("LifecycleSender"), "Sender was not registered")
    check(RenderingServer.get_signal_connection_list("frame_post_draw").size() == before + 1, "Missing frame callback")
    var sent := int(vp.call("get_successful_frame_count"))
    root.remove_child(vp)
    await frames(3)
    check(not registered("LifecycleSender"), "Frozen sender survived EXIT_TREE")
    check(not bool(vp.call("is_sending")), "Detached viewport still reports sending")
    check(int(vp.call("get_successful_frame_count")) == sent, "Detached viewport continued sending")
    check(RenderingServer.get_signal_connection_list("frame_post_draw").size() == before, "Callback survived EXIT_TREE")
    root.add_child(vp)
    await frames(10)
    check(registered("LifecycleSender") and int(vp.call("get_successful_frame_count")) > sent, "Sender did not resume on re-entry")
    vp.set("sender_name", "RenamedSender")
    await frames(5)
    check(not registered("LifecycleSender") and registered("RenamedSender"), "Changing requested name did not replace sender")
    vp.free()
    check(not registered("RenamedSender"), "Sender survived deletion")
    check(RenderingServer.get_signal_connection_list("frame_post_draw").size() == before, "Callback survived deletion")
    finish()
