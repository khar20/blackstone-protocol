extends SceneTree
## Headless logic checks (deterministic terrain parity with sample.html).
## Run: godot --headless -s res://tests/smoke_test.gd
## Reference constants below were produced by running the exact JS noise/height
## functions from sample.html under Node.

var _fails: int = 0
var TERRAIN_SCRIPT: GDScript = load('res://autoload/terrain.gd')

func check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error('ASSERT FAILED: ' + msg)

func approx(a: float, b: float, tol: float = 1e-9) -> bool:
	return abs(a - b) <= tol

func _init() -> void:
	pass

func _initialize() -> void:
	var t: Node = Node.new()
	t.set_script(TERRAIN_SCRIPT)

	check(approx(t.hash2(1, 1, 910), 0.380440000000000), 'hash2(1,1,910)')
	check(approx(t.hash2(5, 5, 910), 0.497310000000000), 'hash2(5,5,910)')
	check(approx(t.hash2(-3, 7, 910), 0.759090000000000), 'hash2(-3,7,910)')
	check(approx(t.hash2(100000, 100000, 910), 0.535830000000000), 'hash2(100000,100000,910)')

	check(approx(t.fractal_noise(0.0, 0.0, 910, 3, 0.5), 0.521261428571429, 1e-12), 'fractal_noise(0,0)')
	check(approx(t.fractal_noise(2.5, -1.5, 210, 3, 0.5), 0.517232609609668, 1e-12), 'fractal_noise(2.5,-1.5)')
	check(approx(t.fractal_noise(-7.0, 3.0, 410, 4, 0.55), 0.600103622846220, 1e-12), 'fractal_noise(-7,3)')

	check(approx(t.biome_field(0.0, 0.0), 3.12756857142857, 1e-11), 'biome_field(0,0)')
	check(approx(t.biome_field(780.0, 300.0), 4.25709317889536, 1e-11), 'biome_field(780,300)')
	check(approx(t.biome_field(-260.0, -880.0), 2.90322160581010, 1e-11), 'biome_field(-260,-880)')

	var height_pts: Array = [
		[0.0, 0.0, 3.85488351243944],
		[780.0, 300.0, 0.0],
		[-260.0, -880.0, 0.0],
		[520.0, -340.0, 0.0],
		[780.0, 320.0, 0.142932557548012],
		[-260.0, -860.0, 0.155228863500274],
		[12.5, -887.25, 6.23031503864077],
		[300.0, 500.0, 5.13417143224371],
		[-1000.0, 700.0, -0.776056252645211],
		[123.4567, -456.789, -1.19922303737390],
		[2000.0, -2000.0, 7.51989038957759],
	]
	for p in height_pts:
		check(approx(t.terrain_height_at(p[0], p[1]), p[2], 1e-9), 'terrain_height_at(%s,%s)' % [p[0], p[1]])

	check(approx(t.terrain_height_at(0.1, 0.1), t.terrain_height_at(0.1, 0.1)), 'height deterministic')
	check(approx(t.biome_field(300.0, -100.0), t.biome_field(300.0, -100.0)), 'biome deterministic')

	check(approx(t.get_effective_ground_height(780.0, 308.0), t.terrain_height_at(780.0, 308.0), 0.1)
		or t.get_effective_ground_height(780.0, 308.0) >= t.terrain_height_at(780.0, 300.0) + 1.9,
		'gateway bastion flat raised ~2')
	check(approx(t.get_effective_ground_height(-260.0, -880.0 + 20.0), t.terrain_height_at(-260.0, -880.0) + 2.0, 0.5),
		'ironhaven flat raised ~2')

	check(approx(t.mission_corridor_dist(780.0, 300.0), 0.0, 1e-6), 'corridor at start = 0')
	check(t.mission_corridor_dist(780.0, 300.0 + 250.0) > 200.0, 'corridor beyond halfWidth')
	check(approx(t.mission_corridor_dist(-260.0, -880.0), 0.0, 1e-6), 'corridor at dest = 0')

	_check_monolith_lcg(t)
	t.free()
	if _fails > 0:
		push_error('%d assertion(s) failed' % _fails)
		quit(1)
	else:
		print('SMOKE TEST OK')
		quit(0)

# Reference: run the same rng loop from sample.html buildBossMonolith and
# compare cell count + first surviving cell against the real inner class.
func _check_monolith_lcg(t: Node) -> void:
	var nx: int = t.BOSS['grid']['x']
	var ny: int = t.BOSS['grid']['y']
	var nz: int = t.BOSS['grid']['z']
	var s: float = float(t.BOSS['cellSize'])
	_ref_seed = 424242
	var ref: Array = []
	for iy in ny:
		var taper := 1.0 - (float(iy) / ny) * 0.55
		for ix in nx:
			for iz in nz:
				if not (_ref_rng() < 0.12):
					var half := Vector3(s * taper * (0.42 + _ref_rng() * 0.12), s / 2.0, s * taper * (0.42 + _ref_rng() * 0.12))
					var center := Vector3((ix - (nx - 1) / 2.0) * s * taper, s / 2.0 + iy * s, (iz - (nz - 1) / 2.0) * s * taper)
					ref.append({ 'center': center, 'half': half })
	var boss_script: GDScript = load('res://scripts/world/boss.gd')
	var zone: Node3D = boss_script.new()
	var host := Node.new()
	zone.setup(Vector3(0, 0, 0), host)
	var m: Node = zone.monolith
	check(m.max_cells == ref.size(), 'monolith cell count (%d vs %d)' % [m.max_cells, ref.size()])
	if ref.size() > 0 and m.cells.size() > 0:
		var a: Vector3 = ref[0]['center']
		var b: Vector3 = m.cells[0]['center']
		check(a.distance_to(b) <= 1e-6, 'monolith first cell center')
		var ha: Vector3 = ref[0]['half']
		var hb: Vector3 = m.cells[0]['half']
		check(ha.distance_to(hb) <= 1e-6, 'monolith first cell half')
	zone.free()
	host.free()

func _si32(x: int) -> int:
	return int(x) & 0xFFFFFFFF if x < 0 else x % 4294967296

var _ref_seed := 0

func _ref_rng() -> float:
	_ref_seed = _si32(_ref_seed * 1664525 + 1013904223)
	return float((_ref_seed & 0xFFFFFFFF) >> 8 & 0xFFFFFF) / 16777216.0