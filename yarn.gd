class_name Yarn
## Hladký materiál a jednoduché tvary.
## Později se tyto tvary nahradí modely .glb z Blenderu, materiál zůstane.

static var _cache := {}

static func mat(c: Color, _soft := true) -> StandardMaterial3D:
	var key := c.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.55
	m.metallic_specular = 0.35
	_cache[key] = m
	return m

static func _add(p: Node3D, mesh: Mesh, pos: Vector3, c: Color, knit: bool, rot := Vector3.ZERO, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos; mi.rotation = rot; mi.scale = sc
	mi.material_override = mat(c, knit)
	p.add_child(mi)
	return mi

## Koule: size = průměr v osách x, y, z.
static func ball(p: Node3D, pos: Vector3, size: Vector3, c: Color, knit := true, rot := Vector3.ZERO) -> MeshInstance3D:
	var s := SphereMesh.new(); s.radial_segments = 14; s.rings = 7
	return _add(p, s, pos, c, knit, rot, size)

static func box(p: Node3D, pos: Vector3, size: Vector3, c: Color, knit := false) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = size
	return _add(p, b, pos, c, knit)

static func cyl(p: Node3D, pos: Vector3, top_r: float, bot_r: float, h: float, c: Color, knit := true, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new(); m.top_radius = top_r; m.bottom_radius = bot_r; m.height = h; m.radial_segments = 12; m.rings = 1
	return _add(p, m, pos, c, knit, rot)

## Soustružený (rotační) tvar z profilu: body (poloměr, výška), odspodu nahoru.
## depth zploští tvar zepředu dozadu.
static func lathe(p: Node3D, profile: Array, pos: Vector3, c: Color, knit := true, rot := Vector3.ZERO, depth := 1.0, segs := 28, sc := Vector3.ONE, a0 := 0.0, a1 := TAU) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := profile.size()
	for i in rings:
		var pr: Vector2 = profile[i]
		for j in segs + 1:
			var a := lerpf(a0, a1, float(j) / segs)
			st.set_uv(Vector2(float(j) / segs, pr.y))
			st.add_vertex(Vector3(sin(a) * pr.x, pr.y, cos(a) * pr.x * depth))
	for i in rings - 1:
		for j in segs:
			var a := i * (segs + 1) + j
			var b := a + segs + 1
			st.add_index(a); st.add_index(b); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(b); st.add_index(b + 1)
	st.generate_normals()
	var mi := _add(p, st.commit(), pos, c, knit, rot, sc)
	if a1 - a0 < TAU - 0.01:
		var m: StandardMaterial3D = mi.material_override.duplicate()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
	return mi

## Poloměr profilu ve výšce y (lineárně mezi body).
static func radius_at(profile: Array, y: float) -> float:
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		if y >= a.y and y <= b.y:
			return lerpf(a.x, b.x, (y - a.y) / max(b.y - a.y, 0.0001))
	return 0.0
