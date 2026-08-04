extends Node

const SENDER_NAME: String = "RedotSpoutDemo"
const PROGRAM_SIZE: Vector2i = Vector2i(1920, 1080)
const REPORT_PATH: String = "user://redot_spout_demo_report.json"

var _program_viewport: SubViewport
var _status_label: Label
var _fps_label: Label
var _elapsed: float = 0.0
var _bridge_loaded: bool = false
var _renderer: String = "unknown"
var _transfer_path: String = "unavailable"
var _sender_registered: bool = false
var _registry_probe_complete: bool = false
var _native_send_ok: bool = false
var _successful_frame_count: int = 0
var _registry_probe_attempts: int = 0
var _diagnostic_spout: Object
var _direct_requested: bool = false
var _benchmark_elapsed: float = 0.0
var _benchmark_frames: int = 0
var _benchmark_complete: bool = false
var _average_fps: float = 0.0


class AnimatedAlphaPattern extends Node2D:
    var elapsed: float = 0.0


    func _process(delta: float) -> void:
        elapsed += delta
        queue_redraw()


    func _draw() -> void:
        var pulse: float = (sin(elapsed * 2.0) + 1.0) * 0.5
        var orbit_center := Vector2(960.0, 540.0)
        var orbit_position := orbit_center + Vector2(cos(elapsed) * 430.0, sin(elapsed * 1.3) * 250.0)

        # The clear area remains transparent so OBS alpha handling is visible.
        draw_rect(Rect2(160.0, 160.0, 1600.0, 760.0), Color(0.03, 0.08, 0.16, 0.72), true)
        draw_rect(Rect2(180.0, 180.0, 1560.0, 720.0), Color(0.15, 0.75, 0.95, 0.85), false, 10.0)
        draw_circle(orbit_center, 175.0 + pulse * 35.0, Color(1.0, 0.34, 0.12, 0.90))
        draw_circle(orbit_center, 95.0 + pulse * 18.0, Color(1.0, 0.85, 0.25, 0.72))
        draw_circle(orbit_position, 92.0, Color(0.20, 1.0, 0.62, 0.78))
        draw_line(Vector2(250.0, 820.0), Vector2(1670.0, 820.0), Color(1.0, 1.0, 1.0, 0.45), 6.0)


func _ready() -> void:
    _renderer = str(RenderingServer.get_current_rendering_method())
    _direct_requested = OS.get_cmdline_user_args().has("--spout-direct")
    _enable_spout_debug_log()
    _create_program_viewport()
    _create_preview_ui()
    _write_report()
    _print_diagnostics()


func _process(delta: float) -> void:
    if not _benchmark_complete:
        _benchmark_elapsed += delta
        _benchmark_frames += 1
        if _benchmark_elapsed >= 5.0:
            _benchmark_complete = true
            _average_fps = float(_benchmark_frames) / _benchmark_elapsed
            if _bridge_loaded:
                _native_send_ok = bool(_program_viewport.call("is_sending"))
                _successful_frame_count = int(_program_viewport.call("get_successful_frame_count"))
            print("[SPOUT_TEST] five_second_average_fps=%.2f" % _average_fps)
            print("[SPOUT_TEST] five_second_successful_frames=%d" % _successful_frame_count)
            _write_report()

    _elapsed += delta
    if _elapsed < 0.5:
        return
    _elapsed = 0.0
    if not _registry_probe_complete:
        _probe_sender_registry()
    if is_instance_valid(_fps_label):
        _fps_label.text = "Runtime FPS: %d" % Engine.get_frames_per_second()


func _create_program_viewport() -> void:
    _bridge_loaded = ClassDB.class_exists(&"SpoutViewport")

    if _bridge_loaded:
        var instance: Object = ClassDB.instantiate(&"SpoutViewport")
        _program_viewport = instance as SubViewport

    if _program_viewport == null:
        _bridge_loaded = false
        _program_viewport = SubViewport.new()

    _program_viewport.name = "ProgramViewport"
    _program_viewport.size = PROGRAM_SIZE
    _program_viewport.transparent_bg = true
    _program_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    _program_viewport.handle_input_locally = false
    add_child(_program_viewport)

    if _bridge_loaded:
        _program_viewport.set("sender_name", SENDER_NAME)
        _program_viewport.set("prefer_direct_texture", _direct_requested)

    _transfer_path = _determine_transfer_path()
    var pattern := AnimatedAlphaPattern.new()
    pattern.name = "AnimatedAlphaPattern"
    _program_viewport.add_child(pattern)


func _enable_spout_debug_log() -> void:
    if not ClassDB.class_exists(&"Spout"):
        return
    _diagnostic_spout = ClassDB.instantiate(&"Spout")
    _diagnostic_spout.call("enable_debug_log", ProjectSettings.globalize_path("user://spout_debug.log"))


func _create_preview_ui() -> void:
    var root := Control.new()
    root.name = "PreviewUI"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    var preview := TextureRect.new()
    preview.name = "ProgramPreview"
    preview.texture = _program_viewport.get_texture()
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(preview)

    var panel := PanelContainer.new()
    panel.name = "DiagnosticsPanel"
    panel.position = Vector2(18.0, 18.0)
    panel.size = Vector2(530.0, 150.0)
    root.add_child(panel)

    var labels := VBoxContainer.new()
    labels.add_theme_constant_override("separation", 6)
    panel.add_child(labels)

    var title := Label.new()
    title.text = "Redot Spout2 Output Addon Demo"
    title.add_theme_font_size_override("font_size", 20)
    labels.add_child(title)

    _status_label = Label.new()
    _status_label.text = "Bridge: %s\nRenderer: %s\nTransfer: %s\nSender: %s (1920x1080 alpha)" % [
        "loaded" if _bridge_loaded else "missing; preview fallback active",
        _renderer,
        _transfer_path,
        SENDER_NAME,
    ]
    labels.add_child(_status_label)

    _fps_label = Label.new()
    _fps_label.text = "Runtime FPS: starting"
    labels.add_child(_fps_label)


func _probe_sender_registry() -> void:
    if not _bridge_loaded or not ClassDB.class_exists(&"Spout"):
        _registry_probe_complete = true
        return

    _registry_probe_attempts += 1
    _native_send_ok = bool(_program_viewport.call("is_sending"))
    _successful_frame_count = int(_program_viewport.call("get_successful_frame_count"))
    var probe: Object = ClassDB.instantiate(&"Spout")
    var sender_count := int(probe.call("get_sender_count"))
    for index: int in sender_count:
        if str(probe.call("get_sender", index)) == SENDER_NAME:
            _sender_registered = true
            break

    _registry_probe_complete = _sender_registered or _registry_probe_attempts >= 5
    if not _registry_probe_complete:
        return

    print("[SPOUT_TEST] native_send_ok=%s" % _native_send_ok)
    print("[SPOUT_TEST] successful_frame_count=%d" % _successful_frame_count)
    print("[SPOUT_TEST] sender_registered=%s" % _sender_registered)
    if is_instance_valid(_status_label):
        _status_label.text += "\nRegistry: %s" % ("sender found" if _sender_registered else "sender not found")
    _write_report()


func _determine_transfer_path() -> String:
    if not _bridge_loaded:
        return "no sender"
    if bool(_program_viewport.call("is_using_direct_texture")):
        return "direct OpenGL texture"
    if _renderer == "gl_compatibility":
        return "disabled by OpenGL crash guard"
    return "GPU-to-CPU image readback"


func _write_report() -> void:
    var report := {
        "bridge_loaded": _bridge_loaded,
        "direct_requested": _direct_requested,
        "engine_version": Engine.get_version_info().get("string", "unknown"),
        "five_second_average_fps": _average_fps,
        "renderer": _renderer,
        "native_send_ok": _native_send_ok,
        "sender_registered": _sender_registered,
        "sender_name": SENDER_NAME,
        "successful_frame_count": _successful_frame_count,
        "program_size": [PROGRAM_SIZE.x, PROGRAM_SIZE.y],
        "transfer_path": _transfer_path,
    }
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file == null:
        push_warning("Could not write Spout test report: %s" % FileAccess.get_open_error())
        return
    file.store_string(JSON.stringify(report, "  "))


func _print_diagnostics() -> void:
    print("[SPOUT_TEST] bridge_loaded=%s" % _bridge_loaded)
    print("[SPOUT_TEST] engine=%s" % Engine.get_version_info().get("string", "unknown"))
    print("[SPOUT_TEST] renderer=%s" % _renderer)
    print("[SPOUT_TEST] transfer_path=%s" % _transfer_path)
    print("[SPOUT_TEST] sender_name=%s" % SENDER_NAME)
    print("[SPOUT_TEST] report=%s" % ProjectSettings.globalize_path(REPORT_PATH))
