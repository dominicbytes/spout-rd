#include "spout_gd.h"

#include <cstdint>
#include <cwchar>
#include <shellapi.h>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/core/error_macros.hpp>

namespace {
String bounded_spout_name(const String &name) {
    const CharString utf8 = name.utf8();
    // Spout uses 256-byte buffers and appends a duplicate-name suffix.
    constexpr int max_bytes = 240;
    if (utf8.length() <= max_bytes) {
        return name;
    }
    int end = max_bytes;
    while ((static_cast<unsigned char>(utf8.get_data()[end]) & 0xC0) == 0x80) {
        --end;
    }
    WARN_PRINT_ONCE("Spout names are limited to 240 UTF-8 bytes; truncating at a character boundary to leave room for duplicate-name suffixes.");
    return String::utf8(utf8.get_data(), end);
}

int bytes_per_pixel(Spout::GLFormat format) {
    switch (format) {
        case Spout::FORMAT_RGB: return 3;
        case Spout::FORMAT_RGBA:
        case Spout::FORMAT_BGRA: return 4;
        default: return 0;
    }
}

int64_t frame_bytes(unsigned int width, unsigned int height, int bpp) {
    // Image dimensions and PackedByteArray allocation must fit the engine APIs.
    if (!width || !height || !bpp || width > INT32_MAX || height > INT32_MAX) {
        return 0;
    }
    const uint64_t size = uint64_t(width) * height * bpp;
    return size <= INT32_MAX ? int64_t(size) : 0;
}
}


bool Spout::uses_separate_render_thread() {
    bool separate = int(ProjectSettings::get_singleton()->get_setting("rendering/driver/threads/thread_model", 1)) == 2;
    // OS.get_cmdline_args() omits engine-consumed flags in Redot 26.3.
    int argc = 0;
    wchar_t **args = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (args) {
        for (int i = 1; i + 1 < argc; ++i) {
            if (std::wcscmp(args[i], L"--") == 0 || std::wcscmp(args[i], L"++") == 0) {
                break;
            }
            if (std::wcscmp(args[i], L"--render-thread") == 0) {
                separate = std::wcscmp(args[i + 1], L"separate") == 0;
            }
        }
        LocalFree(args);
    }
    return separate;
}

void Spout::set_sender_name(const String &p_sender_name) {
    if (p_sender_name.length() < 1) {
        lib->SetSenderName();
    } else {
        lib->SetSenderName(bounded_spout_name(p_sender_name).utf8().get_data());
    }
}

void Spout::release_sender() {
    lib->ReleaseSender();
}

bool Spout::send_fbo(GLuint p_fbo_id, unsigned int p_width, unsigned int p_height, bool p_invert) {
    ERR_FAIL_COND_V_MSG(p_fbo_id != 0 && frame_bytes(p_width, p_height, 4) == 0, false, "Spout.send_fbo requires a valid frame size for a nonzero FBO.");
    return lib->SendFbo(p_fbo_id, p_width, p_height, p_invert);
}

bool Spout::send_texture(GLuint p_texture_id, GLuint p_texture_target, unsigned int p_width, unsigned int p_height, bool p_invert, GLuint p_host_fbo) {
    ERR_FAIL_COND_V_MSG(p_texture_id == 0 || frame_bytes(p_width, p_height, 4) == 0, false, "Spout.send_texture requires a valid texture and frame size.");
    return lib->SendTexture(p_texture_id, p_texture_target, p_width, p_height, p_invert, p_host_fbo);
}

bool Spout::send_image(const Ref<Image> p_image, unsigned int p_width, unsigned int p_height, GLFormat p_gl_format, bool p_invert) {
    ERR_FAIL_COND_V_MSG(p_image.is_null() || p_image->is_empty(), false, "Spout.send_image requires a non-empty Image.");
    return send_bytes(p_image->get_data(), p_width, p_height, p_gl_format, p_invert);
}

bool Spout::send_bytes(const PackedByteArray &p_data, unsigned int p_width, unsigned int p_height, GLFormat p_gl_format, bool p_invert) {
    const int64_t required = frame_bytes(p_width, p_height, bytes_per_pixel(p_gl_format));
    ERR_FAIL_COND_V_MSG(required == 0 || p_data.size() < required, false, "Spout.send_image/send_bytes requires a supported format and enough pixel data for the frame.");
    return lib->SendImage(p_data.ptr(), p_width, p_height, p_gl_format, p_invert);
}

String Spout::get_name() {
    return String::utf8(lib->GetName());
}

unsigned int Spout::get_width() {
    return lib->GetWidth();
}

unsigned int Spout::get_height() {
    return lib->GetHeight();
}

double Spout::get_fps() {
    return lib->GetFps();
}

int Spout::get_frame() {
    return (int)lib->GetFrame();
}

bool Spout::get_cpu() {
    return lib->GetCPU();
}

bool Spout::get_gldx() {
    return lib->GetGLDX();
}

bool Spout::set_cpu_mode(bool p_enabled) {
    return lib->SetCPUmode(p_enabled);
}

void Spout::enable_debug_log(const String &p_path) {
    lib->EnableSpoutLogFile(p_path.utf8().get_data(), false);
    lib->SetSpoutLogLevel(SpoutLibLogLevel::SPOUT_LOG_VERBOSE);
}

String Spout::get_debug_log() {
    return String::utf8(lib->GetSpoutLog().c_str());
}

void Spout::disable_debug_log() {
    lib->SetSpoutLogLevel(SpoutLibLogLevel::SPOUT_LOG_SILENT);
    lib->DisableSpoutLog();
}

void Spout::set_receiver_name(const String p_sender_name) {
    if (p_sender_name.length() < 1) {
        lib->SetReceiverName();
    } else {
        lib->SetReceiverName(bounded_spout_name(p_sender_name).utf8().get_data());
    }
}

void Spout::release_receiver() {
    lib->ReleaseReceiver();
}

bool Spout::receive_texture(GLuint p_texture_id, GLuint p_texture_target, bool p_invert, GLuint p_host_fbo) {
    return lib->ReceiveTexture(p_texture_id, p_texture_target, p_invert, p_host_fbo);
}

bool Spout::_consume_receiver_update() {
    const bool updated = lib->IsUpdated();
    _pending_update = updated || _pending_update;
    return updated;
}

bool Spout::_receive_into(PackedByteArray &buf, int &w, int &h, bool p_invert, GLuint p_host_fbo) {
    // IsUpdated consumes the flag. A changed sender returns before writing pixels,
    // so the next call can allocate for its new dimensions without overflowing.
    _consume_receiver_update();
    const unsigned int width = lib->GetSenderWidth();
    const unsigned int height = lib->GetSenderHeight();
    const int64_t required = frame_bytes(width, height, 4);
    if ((width || height) && required == 0) {
        return false;
    }
    if (buf.resize(required) != OK) {
        return false;
    }
    const bool received = lib->ReceiveImage(buf.ptrw(), FORMAT_RGBA, p_invert, p_host_fbo);
    const bool updated = _consume_receiver_update();
    if (!received || updated || required == 0) {
        return false;
    }
    w = int(width);
    h = int(height);
    return true;
}

bool Spout::receive_buffer(PackedByteArray p_data, GLFormat p_gl_format, bool p_invert, GLuint p_host_fbo) {
    const int bpp = bytes_per_pixel(p_gl_format);
    if (bpp == 0) {
        return false;
    }
    _consume_receiver_update();
    const unsigned int width = lib->GetSenderWidth();
    const unsigned int height = lib->GetSenderHeight();
    const int64_t required = frame_bytes(width, height, bpp);
    if (((width || height) && required == 0) || p_data.size() < required) {
        return false;
    }
    // ptrw() respects copy-on-write. The deprecated by-value API only writes its
    // local copy; it cannot safely mutate the caller's PackedByteArray.
    const bool received = lib->ReceiveImage(p_data.ptrw(), p_gl_format, p_invert, p_host_fbo);
    const bool updated = _consume_receiver_update();
    return received && !updated && required > 0;
}

bool Spout::receive_image(Ref<Image> p_image, GLFormat p_gl_format, bool p_invert, GLuint p_host_fbo) {
    ERR_FAIL_COND_V_MSG(p_image.is_null(), false, "Spout.receive_image requires an Image.");
    ERR_FAIL_COND_V_MSG(bytes_per_pixel(p_gl_format) == 0, false, "Spout.receive_image requires a supported format.");
    int width = 0;
    int height = 0;
    // Images always contain RGBA8, regardless of the legacy transfer-format hint.
    if (!_receive_into(_receive_buffer, width, height, p_invert, p_host_fbo)) {
        return false;
    }
    p_image->set_data(width, height, false, Image::FORMAT_RGBA8, _receive_buffer);
    return true;
}

PackedByteArray Spout::receive_bytes(bool p_invert, GLuint p_host_fbo) {
    int width = 0;
    int height = 0;
    if (!_receive_into(_receive_buffer, width, height, p_invert, p_host_fbo)) {
        return PackedByteArray();
    }
    return _receive_buffer;
}

bool Spout::is_updated() {
    // Always consume the SDK flag, even when an earlier update is latched.
    const bool updated = lib->IsUpdated() || _pending_update;
    _pending_update = false;
    return updated;
}

bool Spout::is_connected() {
    return lib->IsConnected();
}

bool Spout::is_frame_new() {
    return lib->IsFrameNew();
}

String Spout::get_sender_name() {
    return String::utf8(lib->GetSenderName());
}

unsigned int Spout::get_sender_width() {
    return lib->GetSenderWidth();
}

unsigned int Spout::get_sender_height() {
    return lib->GetSenderHeight();
}

double Spout::get_sender_fps() {
    return lib->GetSenderFps();
}

int Spout::get_sender_frame() {
    return (int)lib->GetSenderFrame();
}

bool Spout::get_sender_cpu() {
    return lib->GetSenderCPU();
}

bool Spout::get_sender_gldx() {
    return lib->GetSenderGLDX();
}

unsigned int Spout::get_sender_count() {
    return lib->GetSenderCount();
}

String Spout::get_sender(unsigned int idx) {
    char senderName[256]{};
    if (idx > INT32_MAX || !lib->GetSender(int(idx), senderName)) {
        return String();
    }
    return String::utf8(senderName);
}

void Spout::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_sender_name", "sender_name"), &Spout::set_sender_name);
    ClassDB::bind_method(D_METHOD("set_sender_format"), &Spout::set_sender_format);
    ClassDB::bind_method(D_METHOD("release_sender"), &Spout::release_sender);
    ClassDB::bind_method(D_METHOD("send_fbo", "fbo_id", "width", "height", "invert"), &Spout::send_fbo, DEFVAL(true));
    ClassDB::bind_method(D_METHOD("send_texture", "texture_id", "texture_target", "width", "height", "invert", "host_fbo"), &Spout::send_texture, DEFVAL(true), DEFVAL(0));
    ClassDB::bind_method(D_METHOD("send_image", "image", "width", "height", "gl_format", "invert"), &Spout::send_image, DEFVAL(Spout::FORMAT_RGBA), DEFVAL(true));
    ClassDB::bind_method(D_METHOD("get_name"), &Spout::get_name);
    ClassDB::bind_method(D_METHOD("get_width"), &Spout::get_width);
    ClassDB::bind_method(D_METHOD("get_height"), &Spout::get_height);
    ClassDB::bind_method(D_METHOD("get_fps"), &Spout::get_fps);
    ClassDB::bind_method(D_METHOD("get_frame"), &Spout::get_frame);
    ClassDB::bind_method(D_METHOD("get_handle"), &Spout::get_handle);
    ClassDB::bind_method(D_METHOD("get_cpu"), &Spout::get_cpu);
    ClassDB::bind_method(D_METHOD("get_gldx"), &Spout::get_gldx);
    ClassDB::bind_method(D_METHOD("set_cpu_mode", "enabled"), &Spout::set_cpu_mode);
    ClassDB::bind_method(D_METHOD("enable_debug_log", "path"), &Spout::enable_debug_log);
    ClassDB::bind_method(D_METHOD("get_debug_log"), &Spout::get_debug_log);
    ClassDB::bind_method(D_METHOD("disable_debug_log"), &Spout::disable_debug_log);

    ClassDB::bind_method(D_METHOD("set_receiver_name", "sender_name"), &Spout::set_receiver_name);
    ClassDB::bind_method(D_METHOD("release_receiver"), &Spout::release_receiver);
    ClassDB::bind_method(D_METHOD("receive_texture", "texture_id", "texture_target", "invert", "host_fbo"), &Spout::receive_texture, DEFVAL(0), DEFVAL(0), DEFVAL(false), DEFVAL(0));
    ClassDB::bind_method(D_METHOD("receive_image", "image", "gl_format", "invert", "host_fbo"), &Spout::receive_image, DEFVAL(false), DEFVAL(0));
    ClassDB::bind_method(D_METHOD("receive_buffer", "data", "gl_format", "invert", "host_fbo"), &Spout::receive_buffer, DEFVAL(false), DEFVAL(0));
    ClassDB::bind_method(D_METHOD("receive_bytes", "invert", "host_fbo"), &Spout::receive_bytes, DEFVAL(false), DEFVAL(0));
    ClassDB::bind_method(D_METHOD("is_updated"), &Spout::is_updated);
    ClassDB::bind_method(D_METHOD("is_sender_connected"), &Spout::is_connected);
    ClassDB::bind_method(D_METHOD("is_frame_new"), &Spout::is_frame_new);
    ClassDB::bind_method(D_METHOD("get_sender_name"), &Spout::get_sender_name);
    ClassDB::bind_method(D_METHOD("get_sender_width"), &Spout::get_sender_width);
    ClassDB::bind_method(D_METHOD("get_sender_height"), &Spout::get_sender_height);
    ClassDB::bind_method(D_METHOD("get_sender_format"), &Spout::get_sender_format);
    ClassDB::bind_method(D_METHOD("get_sender_fps"), &Spout::get_sender_fps);
    ClassDB::bind_method(D_METHOD("get_sender_frame"), &Spout::get_sender_frame);
    ClassDB::bind_method(D_METHOD("get_sender_handle"), &Spout::get_sender_handle);
    ClassDB::bind_method(D_METHOD("get_sender_cpu"), &Spout::get_sender_cpu);
    ClassDB::bind_method(D_METHOD("get_sender_gldx"), &Spout::get_sender_gldx);
    ClassDB::bind_method(D_METHOD("select_sender"), &Spout::select_sender);

    ClassDB::bind_method(D_METHOD("get_sender_count"), &Spout::get_sender_count);
    ClassDB::bind_method(D_METHOD("get_sender", "index"), &Spout::get_sender, DEFVAL(0));

    BIND_ENUM_CONSTANT(FORMAT_RGB);
    BIND_ENUM_CONSTANT(FORMAT_RGBA);
    BIND_ENUM_CONSTANT(FORMAT_BGRA);
    BIND_ENUM_CONSTANT(FORMAT_BGRA_EXT); // Backward-compatible alias of FORMAT_BGRA.
    BIND_ENUM_CONSTANT(SPOUT_LOG_SILENT);
    BIND_ENUM_CONSTANT(SPOUT_LOG_VERBOSE);
    BIND_ENUM_CONSTANT(SPOUT_LOG_NOTICE);
    BIND_ENUM_CONSTANT(SPOUT_LOG_WARNING);
    BIND_ENUM_CONSTANT(SPOUT_LOG_ERROR);
    BIND_ENUM_CONSTANT(SPOUT_LOG_FATAL);
    BIND_ENUM_CONSTANT(SPOUT_LOG_NONE);
}

Spout::Spout() {
    lib = GetSpout();
}

Spout::~Spout() {
    if (lib != nullptr) {
        lib->Release();
        lib = nullptr;
    }
}
