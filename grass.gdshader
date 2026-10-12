shader_type spatial;
render_mode cull_disabled, shadows_disabled, alpha_to_coverage;
uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_cutoff = 0.5;
uniform sampler2D blocked_map : filter_nearest, repeat_disable;
uniform bool has_blocked_map = false;
varying vec2 grass_world_xz;

void vertex() {
    grass_world_xz = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz;
        vec3 world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
        float phase = dot(world.xz,vec2(0.61,0.37));
        float speed = TIME*1.3;
        float gust = sin(speed+phase)*0.65+sin(speed*2.37+phase*1.9)*0.35;
        vec2 offset = vec2(0.862,0.507)*(gust*0.5+0.35)*0.07*UV2.x;
        mat3 basis = mat3(MODEL_MATRIX);
        float scale_squared = max(dot(basis[0],basis[0]),0.00001);
        VERTEX += transpose(basis)*vec3(offset.x,0.0,offset.y)/scale_squared;
}

void fragment() {
    if (has_blocked_map && texture(blocked_map,(grass_world_xz+vec2(260.0))/520.0).r>0.5) { discard; }
    vec4 base = texture(base_texture, UV) * tint * COLOR;
    ALPHA = base.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
    ALPHA_ANTIALIASING_EDGE = 0.3;
    ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(base_texture,0));
    ALBEDO = base.rgb;
    NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
    ROUGHNESS = 1.0;
}
