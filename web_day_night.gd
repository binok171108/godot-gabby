extends RefCounted

const SKY_SHADER: Shader = preload("res://web_day_night.gdshader")
const UPDATE_INTERVAL: float = 0.25
var hour: float = 12.0
var day_length_seconds: float = 1200.0
var material: ShaderMaterial
var environment: Environment
var sun: DirectionalLight3D
var _clock: float = 0.0

func configure(world_environment: Environment, sunlight: DirectionalLight3D) -> void:
	environment = world_environment
	sun = sunlight
	material = ShaderMaterial.new()
	material.shader = SKY_SHADER
	var sky: Sky = Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	apply_time(hour)

func advance(delta: float) -> void:
	if material == null or day_length_seconds<=0.0:
		return
	hour = fposmod(hour+delta*24.0/day_length_seconds,24.0)
	_clock += delta
	if _clock<UPDATE_INTERVAL:
		return
	_clock = 0.0
	apply_time(hour)

func apply_time(value: float) -> void:
	hour = fposmod(value,24.0)
	if material == null or environment == null or not is_instance_valid(sun):
		return
	var elevation: float = sin((hour-6.0)*TAU/24.0)
	var daylight: float = smoothstep(-0.15,0.25,elevation)
	material.set_shader_parameter("daylight",daylight)
	sun.rotation_degrees = Vector3((hour-6.0)*-15.0,-32.0,0.0)
	sun.light_energy = maxf(elevation,0.0)*0.5
	environment.ambient_light_color = Color("fff2e1").lerp(Color("7685b3"),1.0-daylight)
	environment.ambient_light_energy = lerpf(0.08,0.25,daylight)
