extends Node
## Deterministic world data and height/noise functions ported 1:1 from the
## JS noise/height stack in sample.html (hash2/valueNoise/fractal noise,
## biome field, base height, effective ground height). Do not swap these for
## FastNoiseLite — terrain shape and biome colors must stay deterministic.

const SHELL_SPEED: float = 98.0
const SHELL_GRAVITY: float = 19.6
const WIND_X: float = 0.5
const WIND_Z: float = 0.2
const MAX_MINING_RANGE: float = 26.0
const MOUSE_SENS: float = 0.0022
const WORLD_BOUND: float = 1250.0

var BIOMES: Array = [
	{ 'name': 'BLEACHED SALT FLATS',        'base': Color(0xe0dad0) / 255.0, 'alt': Color(0xcac3b5) / 255.0 },
	{ 'name': 'OXIDIZED SANDSTONE CANYON',  'base': Color(0xa16e49) / 255.0, 'alt': Color(0xbf855e) / 255.0 },
	{ 'name': 'LICHEN RIVER VALLEY',        'base': Color(0x525c48) / 255.0, 'alt': Color(0x3b4534) / 255.0 },
	{ 'name': 'VOLCANIC OBSIDIAN DUNES',    'base': Color(0x211f1c) / 255.0, 'alt': Color(0x36322b) / 255.0 },
	{ 'name': 'GLACIAL PRISM HIGHLANDS',    'base': Color(0x758896) / 255.0, 'alt': Color(0xa2b7c4) / 255.0 },
	{ 'name': 'SULFUR BASIN & FOOTHILLS',   'base': Color(0x948658) / 255.0, 'alt': Color(0xb8a972) / 255.0 },
]

var OUTPOST_COORDS: Array = [
	{ 'x': 520,  'z': -340, 'name': 'BRIDGES · OUTPOST RUSTWATCH',      'type': 'small', 'flatR': 70,  'dockR': 18 },
	{ 'x': -640, 'z': 480,  'name': 'BRIDGES · HOLLOW SIGNAL RELAY',    'type': 'small', 'flatR': 70,  'dockR': 18 },
	{ 'x': -480, 'z': -600, 'name': 'BRIDGES · VOID NEXUS TERMINAL',    'type': 'small', 'flatR': 70,  'dockR': 18 },
	{ 'x': 780,  'z': 300,  'name': 'BRIDGES · GATEWAY BASTION',        'type': 'town',  'flatR': 140, 'dockR': 30 },
	{ 'x': -260, 'z': -880, 'name': 'BRIDGES · IRONHAVEN DEPOT',        'type': 'town',  'flatR': 140, 'dockR': 30 },
]

var MISSION: Dictionary = {
	'start': { 'x': 780, 'z': 300 },
	'dest': { 'x': -260, 'z': -880 },
	'halfWidth': 200,
	'arriveRadius': 45,
	'failTime': 20,
}

var BOSS: Dictionary = {
	'grid': { 'x': 3, 'y': 10, 'z': 3 },
	'cellSize': 6.0,
	'zoneRadius': 90,
	'eruptionSeconds': 5.0,
	'respawnCooldown': 150,
	'volleyInterval': 4.5,
	'shardsPerVolley': 5,
	'shardSpeed': 55,
	'shardDamage': 6,
	'shockwaveInterval': 10,
	'shockwaveSpeed': 22,
	'shockwaveMaxRadius': 85,
	'shockwaveImpulse': 11000,
	'rewardCrystals': 1800,
}

var NODE_TYPES: Dictionary = {
	'amber':    { 'color': Color(0xd9a05b), 'emissive': Color(0x6b4515), 'pool': 45, 'rate': 1.0, 'value': 1.0, 'name': 'AMBER PRISM CLUSTER' },
	'obsidian': { 'color': Color(0x221f1c), 'emissive': Color(0x141210), 'pool': 65, 'rate': 0.7, 'value': 2.5, 'name': 'OBSIDIAN GEODE SPIRE' },
	'prism':    { 'color': Color(0xb0d5eb), 'emissive': Color(0x3b647f), 'pool': 30, 'rate': 0.9, 'value': 5.5, 'name': 'CELESTIAL PRISM BLOOM' },
}

func clampf(v: float, lo: float, hi: float) -> float:
	return mini(maxi(v, lo), hi)

func _si32(v: int) -> int:
	v = v & 0xFFFFFFFF
	if v >= 0x80000000:
		v -= 0x100000000
	return v

func hash2(x: int, y: int, seed: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + seed * 974521
	n = _si32(n)
	# JS multiplies in IEEE double (result overflows 2^53) then truncates.
	n = _si32(int(float(_si32(n ^ (_si32(n) >> 13))) * 1274126177.0))
	n = _si32(n ^ (_si32(n) >> 16))
	var u: int = n & 0xFFFFFFFF
	return float(u % 100000) / 100000.0

func smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

func value_noise2(x: float, y: float, seed: int) -> float:
	var xi: int = int(floor(x))
	var yi: int = int(floor(y))
	var xf: float = x - xi
	var yf: float = y - yi
	var v00 := hash2(xi, yi, seed)
	var v10 := hash2(xi + 1, yi, seed)
	var v01 := hash2(xi, yi + 1, seed)
	var v11 := hash2(xi + 1, yi + 1, seed)
	var u := smooth(xf)
	var v := smooth(yf)
	return (v00 * (1.0 - u) + v10 * u) * (1.0 - v) + (v01 * (1.0 - u) + v11 * u) * v

func fractal_noise(x: float, y: float, seed: int, octaves: int, persistence: float) -> float:
	var total := 0.0
	var amp := 1.0
	var freq := 1.0
	var max_amp := 0.0
	for i in octaves:
		total += value_noise2(x * freq, y * freq, seed + i * 101) * amp
		max_amp += amp
		amp *= persistence
		freq *= 2.05
	return total / max_amp

func biome_field(x: float, z: float) -> float:
	return fractal_noise(x * 0.0014, z * 0.0014, 910, 3, 0.5) * float(BIOMES.size())

func biome_at(x: float, z: float) -> Dictionary:
	var b := clampf(biome_field(x, z), 0.0, BIOMES.size() - 0.001)
	var idx := int(floor(b))
	var frac := smooth(b - idx)
	var c1: Color = BIOMES[idx]['base']
	var c2: Color = BIOMES[mini(idx + 1, BIOMES.size() - 1)]['base']
	return { 'idx': idx, 'frac': frac, 'c1': c1, 'c2': c2 }

func terrain_height_at(x: float, z: float) -> float:
	var b := clampf(biome_field(x, z), 0.0, BIOMES.size() - 0.001)
	var idx := int(floor(b))
	var frac := smooth(b - idx)

	var plains_h := (fractal_noise(x * 0.008, z * 0.008, 210, 3, 0.5) - 0.5) * 2.2
	var rolling := fractal_noise(x * 0.0055, z * 0.0055, 120, 3, 0.5) * 7.5
	var canyon := -exp(-pow(sin(x * 0.0035 + z * 0.0028) * 3.2, 2.0)) * 7.0
	var peaks := pow(abs(fractal_noise(x * 0.0032, z * 0.0032, 410, 4, 0.55) * 2.0 - 1.0), 1.6) * 30.0 - 5.0
	var dunes := sin(x * 0.014 + z * 0.01) * 4.8 + cos(z * 0.012) * 2.2
	var terraced: float = floor(fractal_noise(x * 0.006, z * 0.006, 530, 3, 0.5) * 4.0) * 2.8

	var h1: float
	var h2: float
	match idx:
		0:
			h1 = plains_h + canyon * 0.3
		1:
			h1 = terraced + canyon * 1.2 + 2.0
		2:
			h1 = canyon * 1.4 - 1.5 + rolling * 0.4
		3:
			h1 = dunes + rolling * 0.6
		4:
			h1 = peaks * 0.8 + rolling * 0.5
		_:
			h1 = rolling + terraced * 0.5
	var idx2 := mini(idx + 1, BIOMES.size() - 1)
	match idx2:
		0:
			h2 = plains_h + canyon * 0.3
		1:
			h2 = terraced + canyon * 1.2 + 2.0
		2:
			h2 = canyon * 1.4 - 1.5 + rolling * 0.4
		3:
			h2 = dunes + rolling * 0.6
		4:
			h2 = peaks * 0.8 + rolling * 0.5
		_:
			h2 = rolling + terraced * 0.5
	var h := h1 * (1.0 - frac) + h2 * frac

	for pt in OUTPOST_COORDS:
		var d: float = sqrt(pow(x - float(pt['x']), 2.0) + pow(z - float(pt['z']), 2.0))
		if d < float(pt['flatR']):
			h *= smooth(d / float(pt['flatR']))
	return h

func get_effective_ground_height(x: float, z: float) -> float:
	var base_h := terrain_height_at(x, z)
	for o in OUTPOST_COORDS:
		var dx: float = x - float(o['x'])
		var dz: float = z - float(o['z'])
		var oy: float = _center_height(o)
		if o['type'] == 'town':
			if abs(dx) <= 60.0 and dz >= -52.0 and dz <= 44.0:
				return maxf(base_h, oy + 2.0)
			if abs(dx) <= 11.0 and dz > 44.0 and dz <= 72.0:
				return maxf(base_h, oy + (72.0 - dz) / 28.0 * 2.0)
		else:
			if abs(dx) <= 22.0 and dz >= -24.0 and dz <= 20.0:
				return maxf(base_h, oy + 2.0)
			if abs(dx) <= 7.0 and dz > 20.0 and dz <= 36.0:
				return maxf(base_h, oy + (36.0 - dz) / 16.0 * 2.0)
	return base_h

var _center_cache: Dictionary = {}

func _center_height(o: Dictionary) -> float:
	var k := o
	if not _center_cache.has(k):
		_center_cache[k] = terrain_height_at(float(o['x']), float(o['z']))
	return _center_cache[k]

func mission_route() -> Vector3:
	var s: Dictionary = MISSION['start']
	var d: Dictionary = MISSION['dest']
	return Vector3(float(d['x']) - float(s['x']), 0.0, float(d['z']) - float(s['z']))

func mission_corridor_dist(px: float, pz: float) -> float:
	var r := mission_route()
	var len2 := r.x * r.x + r.z * r.z
	var t := ((px - float(MISSION['start']['x'])) * r.x + (pz - float(MISSION['start']['z'])) * r.z) / len2
	var tc := clampf(t, 0.0, 1.0)
	var cxp := float(MISSION['start']['x']) + r.x * tc
	var czp := float(MISSION['start']['z']) + r.z * tc
	return sqrt(pow(px - cxp, 2.0) + pow(pz - czp, 2.0))