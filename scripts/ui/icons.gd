class_name Icons
## Zerobinary icon set: glyphs rasterized in code and cached as ImageTextures.
## Placeholders only; real art can replace the draw calls later.

static var _cache: Dictionary = {}
static var AMBER := Color(0xd9a05b)

static func _l(img: Image, p0: Vector2, p1: Vector2) -> void:
	var d: Vector2 = (p1 - p0).abs()
	var steps := int(maxf(d.x, d.y)) + 1
	for i in steps + 1:
		var t := float(i) / steps
		var p := p0.lerp(p1, t)
		var px := int(p.x)
		var py := int(p.y)
		img.set_pixel(px, py, AMBER)
		if px + 1 < img.get_width():
			img.set_pixel(px + 1, py, AMBER)
		if py + 1 < img.get_height():
			img.set_pixel(px, py + 1, AMBER)

static func _poly(img: Image, pts: Array, closed: bool = false) -> void:
	for i in pts.size() - 1:
		_l(img, pts[i], pts[i + 1])
	if closed and pts.size() > 2:
		_l(img, pts[-1], pts[0])

static func _dot(img: Image, c: Vector2, r: float) -> void:
	for y in int(r * 2) + 1:
		for x in int(r * 2) + 1:
			var off := Vector2(c.x - r + x, c.y - r + y)
			if off.distance_to(c) <= r and off.x >= 0.0 and off.y >= 0.0 \
					and off.x < img.get_width() and off.y < img.get_height():
				img.set_pixel(int(off.x), int(off.y), AMBER)

static func _icon(name: String) -> Image:
	var size := 48 if name == 'emblem' else 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match name:
		'cannon':
			_poly(img, [Vector2(4, 18), Vector2(19, 8), Vector2(21.5, 6.5)])
			_poly(img, [Vector2(3, 15), Vector2(8, 15), Vector2(8, 21), Vector2(3, 21)], true)
		'shell':
			_poly(img, [Vector2(12, 2), Vector2(14, 4), Vector2(15, 7), Vector2(15, 10), Vector2(15, 17), Vector2(9, 17), Vector2(9, 10), Vector2(9, 7), Vector2(10, 4.5), Vector2(12, 2)])
			_l(img, Vector2(9, 20), Vector2(15, 20))
		'auto':
			_l(img, Vector2(6, 5), Vector2(6, 14))
			_l(img, Vector2(12, 3), Vector2(12, 14))
			_l(img, Vector2(18, 5), Vector2(18, 14))
			_l(img, Vector2(4, 19), Vector2(20, 19))
		'shield':
			_poly(img, [Vector2(12, 2), Vector2(20, 5), Vector2(20, 11), Vector2(16.5, 18.5), Vector2(12, 20.5), Vector2(7.5, 18.5), Vector2(4, 16), Vector2(4, 11), Vector2(4, 5)], true)
		'arc':
			_poly(img, [Vector2(4, 19), Vector2(5.8, 17), Vector2(7.6, 14.9), Vector2(9.5, 12.7), Vector2(11.4, 10.6), Vector2(13.3, 9), Vector2(15.2, 7.8), Vector2(17, 7), Vector2(19.5, 6.4)])
			_l(img, Vector2(19.5, 6.4), Vector2(15.2, 6.6))
			_l(img, Vector2(19.5, 6.4), Vector2(18.8, 10.5))
		'snow':
			_l(img, Vector2(12, 3), Vector2(12, 21))
			_l(img, Vector2(4.2, 7.5), Vector2(19.8, 16.5))
			_l(img, Vector2(19.8, 7.5), Vector2(4.2, 16.5))
		'thrust':
			_poly(img, [Vector2(5, 6), Vector2(11, 12), Vector2(5, 18)])
			_poly(img, [Vector2(13, 6), Vector2(19, 12), Vector2(13, 18)])
		'cycle':
			var pts := []
			for i in 16:
				pts.append(Vector2(12 + cos(TAU * float(i) / 16.0) * 8.0, 12 + sin(TAU * float(i) / 16.0) * 8.0))
			_poly(img, pts, true)
			_poly(img, [Vector2(17.66, 6.34), Vector2(20, 3), Vector2(15, 3), Vector2(20, 3)])
		'crystal':
			_poly(img, [Vector2(12, 2), Vector2(19, 8), Vector2(16.5, 21), Vector2(7.5, 21), Vector2(5, 8)], true)
			_poly(img, [Vector2(5, 8), Vector2(12, 11), Vector2(19, 8)])
			_l(img, Vector2(12, 11), Vector2(12, 21))
		'wrench':
			_poly(img, [Vector2(8, 10), Vector2(13.5, 4.5), Vector2(17, 8), Vector2(11.5, 13.5), Vector2(8, 10)])
			_poly(img, [Vector2(11.5, 13.5), Vector2(8, 17), Vector2(5, 14), Vector2(8, 11)])
		'exit':
			_poly(img, [Vector2(15, 3), Vector2(6, 3), Vector2(6, 21), Vector2(15, 21)])
			_l(img, Vector2(11, 12), Vector2(21, 12))
			_poly(img, [Vector2(17, 8), Vector2(21, 12), Vector2(17, 16)])
		'emblem':
			_poly(img, [Vector2(24, 3), Vector2(45, 24), Vector2(24, 45), Vector2(3, 24)], true)
			_poly(img, [Vector2(24, 14), Vector2(34, 24), Vector2(24, 34), Vector2(14, 24)], true)
			_l(img, Vector2(10, 38), Vector2(14, 34))
			_l(img, Vector2(38, 10), Vector2(14, 34))
		_:
			_dot(img, Vector2(12, 12), 6.0)
	return img

static func fetch(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var t := ImageTexture.create_from_image(_icon(name))
	_cache[name] = t
	return t