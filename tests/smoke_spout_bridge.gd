extends SceneTree


func _initialize() -> void:
    var bridge_loaded := ClassDB.class_exists(&"SpoutViewport")
    print("[SPOUT_SMOKE] engine=%s" % Engine.get_version_info().get("string", "unknown"))
    print("[SPOUT_SMOKE] bridge_loaded=%s" % bridge_loaded)
    if not bridge_loaded:
        push_error("SpoutViewport was not registered by the native extension.")
        quit(1)
        return
    var instance: Object = ClassDB.instantiate(&"SpoutViewport")
    var viewport := instance as SubViewport
    if viewport == null:
        push_error("SpoutViewport could not be instantiated as a SubViewport.")
        quit(2)
        return
    viewport.free()
    print("[SPOUT_SMOKE] PASS")
    quit(0)
