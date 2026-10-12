shader_type spatial;
render_mode cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D blocked_map : filter_nearest, repeat_disable;
uniform bool has_blocked_map = false;
varying vec2 grass_world_xz;
void vertex() {
    grass_world_xz = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz;
    VERTEX.y += 0.008;
}
void fragment() {
    if (has_blocked_map && texture(blocked_map,(grass_world_xz+vec2(260.0))/520.0).r>0.5) { discard; }
    vec4 base = texture(base_texture,UV)*COLOR;
    ALBEDO = base.rgb;
    ALPHA = base.a;
    ROUGHNESS = 1.0;
}
