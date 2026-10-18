#include "spout_texture.h"

#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/core/error_macros.hpp>

void SpoutTexture::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_sender_name", "sender_name"), &SpoutTexture::set_sender_name);
    ClassDB::bind_method(D_METHOD("get_sender_name"), &SpoutTexture::get_sender_name);
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "sender_name"), "set_sender_name", "get_sender_name");
    ClassDB::bind_method(D_METHOD("set_update_in_editor", "enabled"), &SpoutTexture::set_update_in_editor);
    ClassDB::bind_method(D_METHOD("can_update_in_editor"), &SpoutTexture::can_update_in_editor);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "update_in_editor"), "set_update_in_editor", "can_update_in_editor");
}

void SpoutTexture::set_sender_name(String sender_name) {
    _sender_name = sender_name;

    if (_spout.is_valid()) {
        _spout->release_receiver();
        _spout->set_receiver_name(sender_name);
    }
}

String SpoutTexture::get_sender_name() const {
    return _sender_name;
}

void SpoutTexture::set_update_in_editor(bool enabled) {
    _update_in_editor = enabled;
    if (enabled) {
        initialize_receiver();
    }
}

bool SpoutTexture::can_update_in_editor() const {
    return _update_in_editor;
}

void SpoutTexture::initialize_receiver() {
    if (_spout.is_valid()) {
        return;
    }
    _separate_render_thread = Spout::uses_separate_render_thread();
    _spout = Ref(memnew(Spout));
    _spout->set_receiver_name(_sender_name);
    _image = Image::create_empty(1, 1, false, Image::FORMAT_RGBA8);
    ImageTexture::set_image(_image);
    RenderingServer::get_singleton()->texture_set_force_redraw_if_visible(get_rid(), true);
    RenderingServer::get_singleton()->connect("frame_pre_draw", callable_mp(this, &SpoutTexture::poll_server));
}

void SpoutTexture::poll_server() {
    if (_separate_render_thread || OS::get_singleton()->get_thread_caller_id() != OS::get_singleton()->get_main_thread_id()) {
        WARN_PRINT_ONCE("SpoutTexture does not support a separate render thread; frame skipped.");
        return;
    }
    if (is_queued_for_deletion() || (Engine::get_singleton()->is_editor_hint() && !_update_in_editor)) {
        return;
    }
    const Vector2i previous_size = _image->get_size();
    if (_spout->receive_image(_image, Spout::FORMAT_RGBA, false, 0)) {
        if (_image->get_size() != previous_size) {
            ImageTexture::set_image(_image);
        } else {
            ImageTexture::update(_image);
        }
    }
}

SpoutTexture::SpoutTexture() {
    // Editor imports may instantiate resources without ever displaying them.
    if (!Engine::get_singleton()->is_editor_hint()) {
        initialize_receiver();
    }
}

SpoutTexture::~SpoutTexture() {
    auto rs = RenderingServer::get_singleton();
    auto update = callable_mp(this, &SpoutTexture::poll_server);
    if (rs && rs->is_connected("frame_pre_draw", update)) {
        rs->disconnect("frame_pre_draw", update);
    }
    if (_spout.is_valid()) {
        _spout->release_receiver();
    }
}
