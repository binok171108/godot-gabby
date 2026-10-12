shader_type sky;

uniform float daylight : hint_range(0.0,1.0) = 1.0;
uniform vec3 day_horizon : source_color = vec3(0.66,0.86,0.92);
uniform vec3 day_zenith : source_color = vec3(0.36,0.66,0.88);
uniform vec3 night_horizon : source_color = vec3(0.035,0.045,0.085);
uniform vec3 night_zenith : source_color = vec3(0.005,0.012,0.035);

void sky() {
    float elevation = smoothstep(-0.1,0.8,EYEDIR.y);
    vec3 horizon = mix(night_horizon,day_horizon,daylight);
    vec3 zenith = mix(night_zenith,day_zenith,daylight);
    COLOR = mix(horizon,zenith,elevation);
}
