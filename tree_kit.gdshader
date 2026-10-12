shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform sampler2D origins : filter_nearest, repeat_disable;
uniform bool leaf = true;
uniform int palette_count = 6;
uniform vec3 palette_a[16];
uniform vec3 palette_b[16];
uniform vec3 palette_c[16];
uniform float palette_strength[16];
uniform float alpha_scale[12];
uniform float cutoff = 0.5;
uniform float wind_strength = 0.224;
uniform float wind_speed = 1.0;
uniform float flutter = 0.0;
uniform vec2 wind_direction = vec2(0.861934, 0.50702);
uniform int debug_mode = 0;
varying vec4 tint;
varying vec3 surface_normal;

void vertex() {
    tint = INSTANCE_CUSTOM;
    vec4 origin = texelFetch(origins, ivec2(INSTANCE_ID, 0), 0);
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float phase = TIME * wind_speed - dot(origin.xy, wind_direction) * 0.14 + origin.z * 1.7;
    float gust = sin(phase) * 0.55 + sin(phase * 2.31 + 1.3) * 0.3 + 0.35;
    float weight = pow(clamp(UV2.x, 0.0, 1.0), 1.45);
    vec3 offset = vec3(wind_direction.x, 0.0, wind_direction.y) * gust * wind_strength * tint.w * weight;
    float flicker = sin(phase * 4.7 + UV2.y * 31.0 + world.x * 3.1 + world.z * 2.3) * flutter * tint.w * 0.05 * weight;
    offset += vec3(flicker, flicker * 0.6, -flicker);
    VERTEX += inverse(mat3(MODEL_MATRIX)) * offset;
    surface_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
    if (!leaf && !FRONT_FACING) { discard; }
    vec4 texel = texture(atlas, UV);
    vec3 rgb = texel.rgb;
    if (leaf) {
        int index = clamp(int(floor(tint.x * float(palette_count - 1) + 0.5)), 0, palette_count - 1);
        float lum = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
        float factor = clamp((sqrt(lum) - 0.14) / 0.48, 0.0, 1.0);
        vec3 gradient = factor < 0.5 ? mix(palette_a[index], palette_b[index], factor * 2.0) : mix(palette_b[index], palette_c[index], factor * 2.0 - 1.0);
        rgb = mix(rgb, gradient, palette_strength[index]);
        vec2 pixel_uv = UV * vec2(textureSize(atlas, 0));
        vec2 delta_x = dFdx(pixel_uv), delta_y = dFdy(pixel_uv);
        float level = clamp(log2(max(max(dot(delta_x, delta_x), dot(delta_y, delta_y)), 1.0)) * 0.5, 0.0, 10.0);
        int lower = int(floor(level));
        float coverage = mix(alpha_scale[lower], alpha_scale[lower + 1], fract(level));
        if (texel.a * coverage * smoothstep(1.2, 3.2, length(VERTEX)) <= cutoff) { discard; }
    }
    ALBEDO = rgb * tint.y * vec3(1.0 + 0.08 * tint.z, 1.0, 1.0 - 0.08 * tint.z) * COLOR.rgb;
    NORMAL = normalize((VIEW_MATRIX * vec4(surface_normal, 0.0)).xyz);
    ROUGHNESS = 1.0;
    if (debug_mode > 0) {
        vec3 value = debug_mode == 1 ? clamp(tint.xyz, vec3(0.0), vec3(1.0)) : (debug_mode == 2 ? texel.rgb : COLOR.rgb);
        ALBEDO = vec3(0.0);
        EMISSION = value;
    }
}
