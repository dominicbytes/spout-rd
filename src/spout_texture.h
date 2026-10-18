#ifndef SPOUT_GD_SPOUT_TEXTURE_H
#define SPOUT_GD_SPOUT_TEXTURE_H

#include <godot_cpp/classes/global_constants.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>

#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/rid.hpp>
#include <godot_cpp/variant/variant.hpp>

#include "spout_gd.h"

using namespace godot;

class SpoutTexture : public ImageTexture {
    GDCLASS(SpoutTexture, ImageTexture);

    private:
        Ref<Spout> _spout;
        bool _separate_render_thread{false};
        Ref<Image> _image;
        String _sender_name;
        bool _update_in_editor{false};

        void initialize_receiver();
        void poll_server();
    protected:
        static void _bind_methods();
    public:
        SpoutTexture();
        ~SpoutTexture();

        void set_sender_name(String sender_name);
        String get_sender_name() const;

        void set_update_in_editor(bool enabled);
        bool can_update_in_editor() const;
};

#endif  // SPOUT_GD_SPOUT_TEXTURE_H
