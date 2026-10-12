shader_type spatial;
uniform sampler2D lawn_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dry_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mask_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D lane_texture : filter_linear, repeat_disable;
varying vec3 world_point;
varying vec3 world_normal;

float noise_hash(vec2 point) { return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453); }
float ground_noise(vec2 point) {
    vec2 integer_point = floor(point);
    vec2 fraction = fract(point);
    vec2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
    return mix(mix(noise_hash(integer_point), noise_hash(integer_point + vec2(1.0, 0.0)), blend.x), mix(noise_hash(integer_point + vec2(0.0, 1.0)), noise_hash(integer_point + vec2(1.0, 1.0)), blend.x), blend.y);
}
vec2 rotate_uv(vec2 point) { return vec2(point.x * 0.866 - point.y * 0.5, point.x * 0.5 + point.y * 0.866); }

void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    vec2 ground_point = world_point.xz;
    vec2 world_uv = ground_point / 1.5;
    vec3 lawn = mix(texture(lawn_texture, world_uv).rgb, texture(lawn_texture, rotate_uv(world_uv) * 0.73 + vec2(0.37, 0.61)).rgb, smoothstep(0.35, 0.65, ground_noise(ground_point / 9.0)));
    vec2 first_mask = texture(mask_texture, ground_point / 64.0).rg;
    vec2 second_mask = texture(mask_texture, (rotate_uv(ground_point) + vec2(31.0, 17.0)) / 19.0).rg;
    vec2 combined_mask = vec2(clamp(first_mask.r * 0.62 + second_mask.r * 0.62 - 0.24, 0.0, 1.0), (first_mask.g + second_mask.g) * 0.5);
    vec3 tint = mix(vec3(0.86, 1.07, 0.80), vec3(1.20, 1.00, 0.58), combined_mask.x) * (combined_mask.y * 0.5 + 0.75) * vec3(0.96, 1.36, 2.1);
    float lane = texture(lane_texture, (ground_point + vec2(260.0)) / 520.0).r;
    float detail = (ground_noise(ground_point * 1.1) * 0.5 + ground_noise(ground_point * 2.2 + vec2(5.2, 1.3)) * 0.25 + ground_noise(ground_point * 4.4 + vec2(2.7, 8.1)) * 0.125) / 0.875;
    float edge = (1.0 - lane) * 8.0 / 1.5 + detail * 0.6 - 0.3;
    float dirt = 1.0 - smoothstep(0.62, 1.0, edge);
    float slope = 1.0 - normalize(world_normal).y;
    float region = ground_noise(ground_point * 0.16);
    float rock = smoothstep(0.34, 0.52, slope + (region - 0.5) * 0.1);
    float earth = smoothstep(0.16, 0.3, slope + (region - 0.5) * 0.12);
    float bank = max((1.0 - smoothstep(-0.35, -0.05, world_point.y)) * smoothstep(0.02, 0.1, slope), earth) * (1.0 - rock);
    vec3 soil = mix(mix(lawn * tint, texture(path_texture, rotate_uv(world_uv) * 0.9).rgb, dirt), texture(dry_texture, world_uv).rgb, bank);
    ALBEDO = mix(soil, texture(rock_texture, ground_point / 7.0).rgb * vec3(0.92, 0.93, 0.9), rock);
    ROUGHNESS = 0.95;
}
