#include "spout_viewport.h"

#include <array>
#include <cmath>
#include <cstring>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/core/error_macros.hpp>

namespace {
const std::array<uint8_t, 4096> &srgb_lut() {
    static const std::array<uint8_t, 4096> lut = [] {
        std::array<uint8_t, 4096> values{};
        for (size_t i = 0; i < values.size(); ++i) {
            const float linear = float(i) / 4095.0f;
            const float srgb = linear <= 0.0031308f ? 12.92f * linear : 1.055f * std::pow(linear, 1.0f / 2.4f) - 0.055f;
            values[i] = uint8_t(srgb * 255.0f + 0.5f);
        }
        return values;
    }();
    return lut;
}

float clamp_channel(float value) {
    // Also map NaN to zero before converting to an integer LUT index.
    return value > 0.0f ? (value < 1.0f ? value : 1.0f) : 0.0f;
}
}


void SpoutViewport::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_sender_name", "sender_name"), &SpoutViewport::set_sender_name);
    ClassDB::bind_method(D_METHOD("get_sender_name"), &SpoutViewport::get_sender_name);
    ClassDB::bind_method(D_METHOD("get_active_sender_name"), &SpoutViewport::get_active_sender_name);
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

String SpoutViewport::get_active_sender_name() const {
    return _spout.is_valid() ? _spout->get_name() : String();
}

void SpoutViewport::apply_sender_name() {
    String name = _sender_name;
    if (name.is_empty()) {
        name = ProjectSettings::get_singleton()->get_setting("application/config/name", String());
        if (name.is_empty()) {
            name = "Redot";
        }
    }
    _spout->set_sender_name(name);
    _applied_sender_name = _sender_name;
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
    if (_separate_render_thread || OS::get_singleton()->get_thread_caller_id() != OS::get_singleton()->get_main_thread_id()) {
        WARN_PRINT_ONCE("SpoutViewport does not support a separate render thread; use rendering/driver/threads/thread_model = safe. Frame skipped.");
        return;
    }
    if (is_queued_for_deletion()) {
        return;
    }

    if (!is_inside_tree()) {
        return;
    }

    if (_spout == nullptr) {
        return;
    }

    if (_applied_sender_name != _sender_name) {
        _spout->release_sender();
        apply_sender_name();
    }

    auto rs = RenderingServer::get_singleton();
    auto size = get_size();

    // Redot 26.2's active OpenGL context crashes inside Spout's GL/DX
    // compatibility probe on the tested driver. Keep the safe default inert
    // under GL; direct sharing remains an explicit diagnostic opt-in.
    if (_using_gl_renderer && !_prefer_direct_texture) {
        WARN_PRINT_ONCE("SpoutViewport is inactive under GL Compatibility. prefer_direct_texture is an experimental opt-in with known GL/DX compatibility probe crashes; prefer Forward+ or Mobile CPU readback.");
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
        Ref<Image> image = get_texture()->get_image();
        _last_send_ok = false;
        if (image.is_null() || image->is_empty()) {
            return;
        }
        const Image::Format format = image->get_format();
        if (format == Image::FORMAT_RGB8 || format == Image::FORMAT_RGBA8) {
            _last_send_ok = _spout->send_image(image, image->get_width(), image->get_height(),
                format == Image::FORMAT_RGBA8 ? Spout::FORMAT_RGBA : Spout::FORMAT_RGB, false);
        } else if (format == Image::FORMAT_RGBH || format == Image::FORMAT_RGBAH ||
                   format == Image::FORMAT_RGBF || format == Image::FORMAT_RGBAF) {
            image->convert(Image::FORMAT_RGBAF);
            const PackedByteArray linear = image->get_data();
            const int64_t pixels = int64_t(image->get_width()) * image->get_height();
            if (_hdr_buffer.resize(pixels * 4) != OK) {
                return;
            }
            const uint8_t *src = linear.ptr();
            uint8_t *dst = _hdr_buffer.ptrw();
            const auto &lut = srgb_lut();
            for (int64_t i = 0; i < pixels; ++i) {
                float rgba[4];
                // Byte arrays do not promise float alignment.
                std::memcpy(rgba, src + i * sizeof(rgba), sizeof(rgba));
                for (int channel = 0; channel < 3; ++channel) {
                    dst[i * 4 + channel] = lut[size_t(clamp_channel(rgba[channel]) * 4095.0f + 0.5f)];
                }
                // Alpha is linear coverage, not an sRGB colour channel.
                dst[i * 4 + 3] = uint8_t(clamp_channel(rgba[3]) * 255.0f + 0.5f);
            }
            _last_send_ok = _spout->send_bytes(_hdr_buffer, image->get_width(), image->get_height(), Spout::FORMAT_RGBA, false);
        } else {
            WARN_PRINT_ONCE("SpoutViewport readback has an unsupported Image format.");
        }
    }

    if (_last_send_ok) {
        _successful_frame_count++;
    }
}

void SpoutViewport::_notification(int p_what) {
    if (p_what == NOTIFICATION_ENTER_TREE && !Engine::get_singleton()->is_editor_hint()) {
        _separate_render_thread = Spout::uses_separate_render_thread();
        _using_gl_renderer = RenderingServer::get_singleton()->get_current_rendering_method() == String("gl_compatibility");
        _spout = Ref(memnew(Spout));
        if (!is_using_direct_texture()) {
            _spout->set_cpu_mode(true);
        }
        apply_sender_name();
        RenderingServer::get_singleton()->connect("frame_post_draw", callable_mp(this, &SpoutViewport::poll_server));
    } else if (p_what == NOTIFICATION_EXIT_TREE) {
        auto rs = RenderingServer::get_singleton();
        auto update = callable_mp(this, &SpoutViewport::poll_server);
        if (rs->is_connected("frame_post_draw", update)) {
            rs->disconnect("frame_post_draw", update);
        }
        if (_spout.is_valid()) {
            _spout->release_sender();
            _spout.unref();
        }
        _last_send_ok = false;
    }
}

SpoutViewport::SpoutViewport() {
}

SpoutViewport::~SpoutViewport() {
    if (_spout.is_valid()) {
        _spout->release_sender();
    }
}
