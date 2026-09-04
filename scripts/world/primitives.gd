class_name Primitives
## Zerobinary geometry: builds ArrayMesh out of axis-aligned boxes,
## cylinders and rings using SurfaceTool. Vertex colors carry the palette.
## SurfaceTool has no vertex-count getter, so helpers thread a counter array.

static func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	st.set_color(Color.WHITE)
	st.set_uv(Vector2.ZERO)
	return st

static func add_box(st: SurfaceTool, ctr: Array, minv: Vector3, maxv: Vector3, color: Color) -> void:
	var c: Array[Vector3] = [
		Vector3(minv.x, minv.y, minv.z), Vector3(maxv.x, minv.y, minv.z),
		Vector3(maxv.x, maxv.y, minv.z), Vector3(minv.x, maxv.y, minv.z),
		Vector3(minv.x, minv.y, maxv.z), Vector3(maxv.x, minv.y, maxv.z),
		Vector3(maxv.x, maxv.y, maxv.z), Vector3(minv.x, maxv.y, maxv.z),
	]
	var faces := [
		[0, 1, 2, 3, Vector3(0, 0, -1)],
		[5, 4, 7, 6, Vector3(0, 0, 1)],
		[4, 0, 3, 7, Vector3(-1, 0, 0)],
		[1, 5, 6, 2, Vector3(1, 0, 0)],
		[3, 2, 6, 7, Vector3(0, 1, 0)],
		[4, 5, 1, 0, Vector3(0, -1, 0)],
	]
	for f in faces:
		var n: Vector3 = f[4]
		var base: int = ctr[0]
		for vi in range(4):
			st.set_normal(n)
			st.set_color(color)
			st.add_vertex(c[f[vi]])
			ctr[0] += 1
		for i in [0, 1, 2, 0, 2, 3]:
			st.add_index(base + i)

static func box_mesh(boxes: Array) -> ArrayMesh:
	var st := _st()
	var ctr := [0]
	for b in boxes:
		add_box(st, ctr, b['min'], b['max'], b['color'])
	return st.commit()

static func add_cylinder(st: SurfaceTool, ctr: Array, c: Vector3, r0: float, r1: float, y0: float, y1: float, segs: int, color: Color) -> void:
	var top: float = y1
	var bottom: float = y0
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var x0: float = cos(a0)
		var z0: float = sin(a0)
		var x1: float = cos(a1)
		var z1: float = sin(a1)
		var n: Vector3 = Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5).normalized()
		var base: int = ctr[0]
		st.set_normal(n)
		st.set_color(color)
		st.add_vertex(c + Vector3(x0 * r0, bottom, z0 * r0))
		st.add_vertex(c + Vector3(x1 * r0, bottom, z1 * r0))
		st.add_vertex(c + Vector3(x1 * r1, top, z1 * r1))
		st.add_vertex(c + Vector3(x0 * r1, top, z0 * r1))
		ctr[0] += 4
		for tri in [0, 1, 2, 0, 2, 3]:
			st.add_index(base + tri)
	st.set_normal(Vector3.UP)
	st.set_color(color)
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var base: int = ctr[0]
		st.add_vertex(c + Vector3(cos(a0) * r1, top, sin(a0) * r1))
		st.add_vertex(c + Vector3(cos(a1) * r1, top, sin(a1) * r1))
		st.add_vertex(c + Vector3(0, top, 0))
		ctr[0] += 3
		st.add_index(base + 0)
		st.add_index(base + 1)
		st.add_index(base + 2)
	st.set_normal(Vector3.DOWN)
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var base: int = ctr[0]
		st.add_vertex(c + Vector3(cos(a1) * r0, bottom, sin(a1) * r0))
		st.add_vertex(c + Vector3(cos(a0) * r0, bottom, sin(a0) * r0))
		st.add_vertex(c + Vector3(0, bottom, 0))
		ctr[0] += 3
		st.add_index(base + 0)
		st.add_index(base + 1)
		st.add_index(base + 2)

static func cylinder_mesh(c: Vector3, r0: float, r1: float, y0: float, y1: float, segs: int, color: Color) -> ArrayMesh:
	var st := _st()
	var ctr := [0]
	add_cylinder(st, ctr, c, r0, r1, y0, y1, segs, color)
	return st.commit()

static func add_ring(st: SurfaceTool, ctr: Array, c: Vector3, r0: float, r1: float, y: float, segs: int, color: Color, up: bool = true) -> void:
	st.set_normal(Vector3.UP if up else Vector3.DOWN)
	st.set_color(color)
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var p0: Vector3 = c + Vector3(cos(a0) * r0, y, sin(a0) * r0)
		var p1: Vector3 = c + Vector3(cos(a1) * r0, y, sin(a1) * r0)
		var p2: Vector3 = c + Vector3(cos(a1) * r1, y, sin(a1) * r1)
		var p3: Vector3 = c + Vector3(cos(a0) * r1, y, sin(a0) * r1)
		var base: int = ctr[0]
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(p2)
		st.add_vertex(p3)
		ctr[0] += 4
		st.add_index(base + 0)
		st.add_index(base + 1)
		st.add_index(base + 3)
		st.add_index(base + 1)
		st.add_index(base + 2)
		st.add_index(base + 3)

static func ring_mesh(c: Vector3, r0: float, r1: float, y: float, segs: int, color: Color) -> ArrayMesh:
	var st := _st()
	var ctr := [0]
	add_ring(st, ctr, c, r0, r1, y, segs, color)
	return st.commit()
