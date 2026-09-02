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

func _thread_fill_heights(n: int, step: float, half: float) -> void:
	# corre en Thread — sin await, sin acceso a SceneTree
	for z in n:
		for x in n:
			var wx := -half + x * step
			var wz := -half + z * step
			_h_arr[z * n + x] = TERRAIN.get_effective_ground_height(wx, wz)

func build() -> void:
	if _built:
		return
	_built = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var step := WORLD_SIZE / float(SEG)
	var half := WORLD_SIZE * 0.5
	var n: int = SEG + 1
	_h_arr = PackedFloat32Array()
	_h_arr.resize(n * n)
	# precalentar cache de centros (Dictionary no thread-safe) en main
	for o in TERRAIN.OUTPOST_COORDS:
		TERRAIN.get_effective_ground_height(float(o['x']), float(o['z']))
	# ponytail: alturas en Thread → 0ms en main (antes 280/frame =21ms hitch, nunca debe bajar fps)
	var th := Thread.new()
	th.start(_thread_fill_heights.bind(n, step, half))
	while th.is_alive():
		await get_tree().process_frame
	th.wait_to_finish()
	var h_arr := _h_arr
	# vértices aún en main pero chunk pequeño: 280/frame ≈ 8-10ms tras optimizar sin heights
	var v_cnt := 0
	for z in n:
		for x in n:
			var wx := -half + x * step
			var wz := -half + z * step
			var h: float = h_arr[z * n + x]
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
			var nx := h_arr[maxi(z - 1, 0) * n + x] - h_arr[mini(z + 1, n - 1) * n + x]
			var nz := h_arr[z * n + maxi(x - 1, 0)] - h_arr[z * n + mini(x + 1, n - 1)]
			st.set_normal(Vector3(nx, 2.0 * step, nz).normalized())
			st.set_color(col)
			st.add_vertex(Vector3(wx, h, wz))
			v_cnt += 1
			if v_cnt % 420 == 0:
				await get_tree().process_frame
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
