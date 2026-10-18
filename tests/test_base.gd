extends SceneTree

var failed: bool = false
var mode: String = ""
var logger: Object

func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    mode = args[0] if not args.is_empty() else ""
    if not ClassDB.class_exists(&"Spout"):
        push_error("Spout extension did not load")
        quit(1)
        return
    logger = ClassDB.instantiate(&"Spout")
    logger.call("enable_debug_log", ProjectSettings.globalize_path("res://spout-test.log"))
    call_deferred("run")

func check(condition: bool, message: String) -> void:
    if not condition:
        failed = true
        push_error(message)

func frames(count: int) -> void:
    for i in count:
        await process_frame

func make_viewport(sender: String, opaque: bool = false, hdr: bool = false) -> SubViewport:
    var vp := ClassDB.instantiate(&"SpoutViewport") as SubViewport
    vp.size = Vector2i(64, 32)
    vp.transparent_bg = not opaque
    vp.use_hdr_2d = hdr
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    vp.set("sender_name", sender)
    var rect := ColorRect.new()
    rect.color = Color(1, 0.5, 0, 1)
    rect.size = Vector2(256, 256)
    vp.add_child(rect)
    root.add_child(vp)
    return vp

func finish() -> void:
    print("[SPOUT_TEST] %s %s" % ["FAIL" if failed else "PASS", mode])
    logger = null
    quit(1 if failed else 0)
