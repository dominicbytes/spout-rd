#include "spout_viewport.h"

void SpoutViewport::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_sender_name", "sender_name"), &SpoutViewport::set_sender_name);
    ClassDB::bind_method(D_METHOD("get_sender_name"), &SpoutViewport::get_sender_name);
    ClassDB::bind_method(D_METHOD("set_prefer_direct_texture", "enabled"), &SpoutViewport::set_prefer_direct_texture);
    ClassDB::bind_method(D_METHOD("get_prefer_direct_texture"), &SpoutViewport::get_prefer_direct_texture);
    ClassDB::bind_method(D_METHOD("is_using_direct_texture"), &SpoutViewport::is_using_direct_texture);
    ClassDB::bind_method(D_METHOD("is_sending"), &SpoutViewport::is_sending);
    ClassDB::bind_method(D_METHOD("get_successful_frame_count"), &SpoutViewport::get_successful_frame_count);
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "sender_name"), "set_sender_name", "get_sender_name");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "prefer_direct_texture"), "set_prefer_direct_texture", "get_prefer_direct_texture");
}

void SpoutViewport::set_sender_name(String sender_name) {
    _sender_name = sender_name;
}

String SpoutViewport::get_sender_name() const {
    return _sender_name;
}

void SpoutViewport::set_prefer_direct_texture(bool p_enabled) {
    _prefer_direct_texture = p_enabled;
}

bool SpoutViewport::get_prefer_direct_texture() const {
    return _prefer_direct_texture;
}

bool SpoutViewport::is_using_direct_texture() const {
    return _using_gl_renderer && _prefer_direct_texture;
}

bool SpoutViewport::is_sending() const {
    return _last_send_ok;
}

int64_t SpoutViewport::get_successful_frame_count() const {
    return _successful_frame_count;
}

void SpoutViewport::poll_server() {
    if (is_queued_for_deletion()) {
        return;
    }

    if (!is_inside_tree()) {
        return;
    }

    if (_spout == nullptr) {
        return;
    }

    if (_spout->get_sender_name() != _sender_name) {
        _spout->release_sender();
        _spout->set_sender_name(_sender_name);
    }

    auto rs = RenderingServer::get_singleton();
    auto size = get_size();

    // Redot 26.2's active OpenGL context crashes inside Spout's GL/DX
    // compatibility probe on the tested driver. Keep the safe default inert
    // under GL; direct sharing remains an explicit diagnostic opt-in.
    if (_using_gl_renderer && !_prefer_direct_texture) {
        _last_send_ok = false;
        return;
    }
    
    // spout's API only supports GL texture handles at this moment.  If it exposes DX12 or Vulkan resource handles,
    // switch to use RenderingDevice's get_driver_resource and send the texture handle directly
    if (is_using_direct_texture()) {
        RID texture_rid = rs->viewport_get_texture(get_viewport_rid());
        if (!texture_rid.is_valid()) {
            return;
        }

        uint64_t native_handle = rs->texture_get_native_handle(texture_rid);
        if (native_handle == 0) {
            return;
        }

        _last_send_ok = _spout->send_texture(
            native_handle,
            0x0DE1, // GL_TEXTURE_2D
            size.x,
            size.y,
            false
        );
    }
    // potentially slow, copies from GPU to CPU to send as pixels
    else {
        _last_send_ok = _spout->send_image(
            get_texture()->get_image(),
            size.x,
            size.y,
            has_transparent_background() ? Spout::GLFormat::FORMAT_RGBA : Spout::GLFormat::FORMAT_RGB,
            false
        );
    }

    if (_last_send_ok) {
        _successful_frame_count++;
    }
}

void SpoutViewport::_notification(int p_what) {
    if (p_what == NOTIFICATION_READY && !Engine::get_singleton()->is_editor_hint()) {
        _spout = Ref(memnew(Spout));
        if (!is_using_direct_texture()) {
            _spout->set_cpu_mode(true);
        }

        auto _update = callable_mp(this, &SpoutViewport::poll_server);

        RenderingServer::get_singleton()->connect(
            "frame_post_draw",
            _update
        );
    }
    else if (p_what == NOTIFICATION_PREDELETE) {
        if (_spout != nullptr) {
            _spout->release_sender();
            _last_send_ok = false;
        }    
    }
}

SpoutViewport::SpoutViewport() {
    // create a placeholder image for spout
    _sender_name = String("");
    // detect renderer type to know if we can send textures directly over spout
    _using_gl_renderer = RenderingServer::get_singleton()->get_current_rendering_method() == String("gl_compatibility");
}

SpoutViewport::~SpoutViewport() {
    if (_spout != nullptr) {
        _spout->release_sender();
    }
}
