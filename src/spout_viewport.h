#ifndef SPOUT_GD_SPOUT_VIEWPORT_H
#define SPOUT_GD_SPOUT_VIEWPORT_H

#include <godot_cpp/classes/global_constants.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/classes/viewport_texture.hpp>
#include <godot_cpp/classes/sub_viewport.hpp>

#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/rid.hpp>

#include "spout_gd.h"

using namespace godot;

class SpoutViewport : public SubViewport {
    GDCLASS(SpoutViewport, SubViewport);

    private:
        Ref<Spout> _spout;
        bool _separate_render_thread{false};
        String _sender_name;
        String _applied_sender_name;
        PackedByteArray _hdr_buffer;
        bool _using_gl_renderer{false};
        bool _prefer_direct_texture{false};
        bool _last_send_ok{false};
        int64_t _successful_frame_count{0};
        
        void apply_sender_name();
        void poll_server();
    protected:
        static void _bind_methods();
        void _notification(int p_what);
    public:
        SpoutViewport();
        ~SpoutViewport();

        void set_sender_name(String sender_name);
        String get_sender_name() const;
        String get_active_sender_name() const;
        void set_prefer_direct_texture(bool p_enabled);
        bool get_prefer_direct_texture() const;
        bool is_using_direct_texture() const;
        bool is_sending() const;
        int64_t get_successful_frame_count() const;
};

#endif  // SPOUT_GD_SPOUT_VIEWPORT_H
