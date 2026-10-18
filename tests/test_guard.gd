extends "res://tests/test_base.gd"

func run() -> void:
    if mode == "separate_config":
        ProjectSettings.set_setting("rendering/driver/threads/thread_model", 2)
    var vp := make_viewport("GuardSender")
    await frames(15)
    check(int(vp.call("get_successful_frame_count")) == 0, "Unsupported renderer/thread sent frames")
    check(not bool(vp.call("is_sending")), "Skipped sender reports success")
    vp.free()
    finish()
