extends Node
## Capa de ambiente: Environment + DirectionalLight + scar ring.
## Extraido de world.gd::_build_environment/_build_scar/_update_environment.
## Vive como hijo de World (Node3D), pero sus nodos son hijos de World para iluminar todo.

const PRIMITIVES = preload("res://scripts/world/primitives.gd")

var sky_peace := Color('#b5aea0')
var sky_combat := Color('#1a1916')
var fog_near_peace := 70.0
var fog_far_peace := 520.0
var fog_near_combat := 30.0
var fog_far_combat := 320.0
var sun_color_peace := Color('#f5e9ce')
var sun_color_combat := Color('#1a1916')

var _env: Environment
var _sun: DirectionalLight3D
var _scar: MeshInstance3D
var _scar_mat: StandardMaterial3D
var _scar_radius := 0.0
var _scar_target := 0.0
var _world: Node3D

func setup(world: Node3D) -> void:
	_world = world
	_build_environment()
	_build_scar()

func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = sky_peace
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color('#d9d3bf')
	_env.ambient_light_energy = 0.85
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_light_color = Color(Color('#b5aea0'), 0.85)
	_env.fog_depth_begin = fog_near_peace
	_env.fog_depth_end = fog_far_peace
	_env.fog_sky_affect = 0.35
	_env.glow_enabled = true
	_env.glow_intensity = 0.18
	_env.glow_bloom = 0.22
	var we := WorldEnvironment.new()
	we.environment = _env
	_world.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.light_color = sun_color_peace
	_sun.light_energy = 1.15
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.05
	_sun.shadow_normal_bias = 0.8
	_sun.rotation_degrees = Vector3(-52.0, 24.0, 0.0)
	_world.add_child(_sun)

func _build_scar() -> void:
	_scar_mat = StandardMaterial3D.new()
	_scar_mat.albedo_color = Color('#12100d')
	_scar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_scar_mat.albedo_color.a = 0.0
	_scar_mat.roughness = 1.0
	_scar = MeshInstance3D.new()
	_scar.name = "ScarRing"
	_scar.mesh = PRIMITIVES.ring_mesh(Vector3.ZERO, 0.0001, 1.0, 0.0, 36, Color('#12100d'))
	_scar.mesh.surface_set_material(0, _scar_mat)
	_scar.rotation.x = -PI / 2
	_scar.position.y = 0.05
	_world.add_child(_scar)

func update_env(delta: float, monolith: Node) -> void:
	var in_combat: bool = monolith != null and monolith.is_active() and monolith.get_parent().engaged()
	var target_sky: Color = sky_combat if in_combat else sky_peace
	_env.background_color = _env.background_color.lerp(target_sky, delta * 0.8)
	_env.fog_light_color = _env.fog_light_color.lerp(target_sky, delta * 0.8)
	_env.fog_depth_begin = lerpf(_env.fog_depth_begin, fog_near_combat if in_combat else fog_near_peace, delta * 0.8)
	_env.fog_depth_end = lerpf(_env.fog_depth_end, fog_far_combat if in_combat else fog_far_peace, delta * 0.8)
	_sun.light_color = _sun.light_color.lerp(sun_color_combat if in_combat else sun_color_peace, delta * 0.8)
	_scar_target = TERRAIN.BOSS['grid']['y'] * TERRAIN.BOSS['cellSize'] * 2.1 if (in_combat and monolith) else 0.0
	_scar_radius = lerpf(_scar_radius, _scar_target, delta * 1.2)
	if in_combat and monolith:
		_scar.position = Vector3(monolith.position.x, TERRAIN.get_effective_ground_height(monolith.position.x, monolith.position.z) + 0.05, monolith.position.z)
	_scar.scale = Vector3(maxf(0.001, _scar_radius), 1.0, maxf(0.001, _scar_radius))
	_scar_mat.albedo_color.a = minf(0.65, _scar_radius / maxf(_scar_target, 0.001) * 0.65)
