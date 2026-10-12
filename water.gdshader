shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D ripple : repeat_enable, filter_linear_mipmap;
varying vec3 world;

float waves(vec2 point, float time) {
    vec3 first = texture(ripple, point * 0.085 + vec2(time * 0.021, time * 0.009)).rgb;
    vec2 rotated = vec2(point.x * 0.8 - point.y * 0.6, point.x * 0.6 + point.y * 0.8);
    vec3 second = texture(ripple, rotated * 0.137 + vec2(time * -0.012, time * 0.024)).rgb;
    return dot(first, vec3(0.3, 0.55, 0.15)) * 0.55 + dot(second, vec3(0.3, 0.55, 0.15)) * 0.45;
}

vec3 to_linear(vec3 color) {
    return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), color));
}

void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 point = world.xz;
    float height = waves(point, TIME);
    float near_weight = clamp(1.0 - distance(world, CAMERA_POSITION_WORLD) / 90.0, 0.15, 1.0);
    vec3 normal = normalize(vec3(-(waves(point + vec2(0.35, 0.0), TIME) - height) * near_weight * 3.0, 1.0, -(waves(point + vec2(0.0, 0.35), TIME) - height) * near_weight * 3.0));
    vec3 view = normalize(CAMERA_POSITION_WORLD - world);
    float fresnel = pow(1.0 - max(dot(normal, view), 0.0), 4.0);
    vec3 base = mix(vec3(0.11, 0.34, 0.5), vec3(0.24, 0.55, 0.66), smoothstep(0.25, 0.75, height));
    vec3 sky = mix(base, vec3(0.66, 0.82, 0.96), clamp(fresnel * 0.75 + 0.08, 0.0, 0.8));
    float edge = min(UV.x, 1.0 - UV.x) - sin(point.x * 0.7 + point.y * 0.5 + TIME * 1.6) * 0.02;
    float foam = (1.0 - smoothstep(0.0, 0.07, edge)) * (height * 0.45 + 0.55);
    ALBEDO = to_linear(mix(sky, vec3(0.95, 0.98, 1.0), foam * 0.7));
    vec3 reflection = reflect(-normalize(vec3(0.4, 0.8, 0.3)), normal);
    EMISSION = vec3(1.0, 0.97, 0.88) * pow(max(dot(reflection, view), 0.0), 220.0) * 0.9 * near_weight;
    NORMAL = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);
    ROUGHNESS = 1.0;
}
