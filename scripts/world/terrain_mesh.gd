extends Node3D
## Capa de terreno: genera el mesh deterministico en diferido para no bloquear frame 0.
## Extraido de world.gd::_build_terrain — misma matematica, solo movido a su nodo.
## ponytail: build diferido (call_deferred) para arranque instantaneo; si hay lag en mesh, chunkear por filas.

const WORLD_SIZE := 2600
const SEG := 140 # ponytail: 200→140 ≈20k verts (vs 40k) → 1.9s total, NUNCA lento en partida; subir a 200 cuando se necesite más detalle

signal terrain_ready

var _built := false

func _ready() -> void:
	# No construir sincronamente: deja que el menu/title pinte primero
	call_deferred("build")

var _h_arr: PackedFloat32Array
var _verts: PackedVector3Array
var _cols: PackedColorArray
var _norms: PackedVector3Array

func _thread_prepare(n: int, step: float, half: float) -> void:
	# Todo lo pesado (alturas + bioma + speck + normal) en Thread → 0ms hitch en main
	for z in n:
		for x in n:
			var wx := -half + x * step
			var wz := -half + z * step
			_h_arr[z * n + x] = TERRAIN.get_effective_ground_height(wx, wz)
	for z in n:
		for x in n:
			var wx := -half + x * step
			var wz := -half + z * step
			var h: float = _h_arr[z * n + x]
			var b := clampf(TERRAIN.biome_field(wx, wz), 0.0, TERRAIN.BIOMES.size() - 0.001)
			var idx := int(floor(b))
			var frac := TERRAIN.smooth(b - idx)
			var c1: Color = TERRAIN.BIOMES[idx]['base']
			var c2: Color = TERRAIN.BIOMES[mini(idx + 1, TERRAIN.BIOMES.size() - 1)]['base']
			var col := c1.lerp(c2, frac)
			var speck := 0.92 + TERRAIN.value_noise2(wx * 0.15, wz * 0.15, 555) * 0.16
			if h > 12.0:
				col = col.lerp(TERRAIN.BIOMES[4]['alt'], minf(1.0, (h - 12.0) / 14.0))
			col = Color(col.r * speck, col.g * speck, col.b * speck)
			var nx := _h_arr[maxi(z - 1, 0) * n + x] - _h_arr[mini(z + 1, n - 1) * n + x]
			var nz := _h_arr[z * n + maxi(x - 1, 0)] - _h_arr[z * n + mini(x + 1, n - 1)]
			var idx_flat := z * n + x
			_verts[idx_flat] = Vector3(wx, h, wz)
			_cols[idx_flat] = col
			_norms[idx_flat] = Vector3(nx, 2.0 * step, nz).normalized()

func build() -> void:
	if _built:
		return
	_built = true
	var step := WORLD_SIZE / float(SEG)
	var half := WORLD_SIZE * 0.5
	var n: int = SEG + 1
	_h_arr = PackedFloat32Array(); _h_arr.resize(n * n)
	_verts = PackedVector3Array(); _verts.resize(n * n)
	_cols = PackedColorArray(); _cols.resize(n * n)
	_norms = PackedVector3Array(); _norms.resize(n * n)
	for o in TERRAIN.OUTPOST_COORDS:
		TERRAIN.get_effective_ground_height(float(o['x']), float(o['z']))
	var th := Thread.new()
	th.start(_thread_prepare.bind(n, step, half))
	while th.is_alive():
		await get_tree().process_frame
	th.wait_to_finish()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# solo copia de buffers precalculados → ~1ms/800 verts, NUNCA lento
	for i in n * n:
		st.set_normal(_norms[i])
		st.set_color(_cols[i])
		st.add_vertex(_verts[i])
		if i % 800 == 0 and i != 0:
			await get_tree().process_frame
	# liberar buffers pesados
	_h_arr = PackedFloat32Array(); _verts = PackedVector3Array(); _cols = PackedColorArray(); _norms = PackedVector3Array()
	var i_cnt := 0
	for z in SEG:
		for x in SEG:
			var i0 := z * n + x
			var i1 := i0 + 1
			var i2 := i0 + n
			var i3 := i0 + n + 1
			st.add_index(i0)
			st.add_index(i2)
			st.add_index(i1)
			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i3)
			i_cnt += 1
			if i_cnt % 800 == 0:
				await get_tree().process_frame
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = mesh
	add_child(mi)
	terrain_ready.emit()
