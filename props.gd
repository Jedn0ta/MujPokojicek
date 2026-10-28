class_name Props
## Další věci poskládané v kódu ve stejném hladkém stylu: zvířátka, dobroty,
## ovoce a zelenina, dárky a hvězdičky. Pohyblivé části mají meta "anim"
## a hýbe s nimi room.gd.

static func glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.95, 1.0, 0.25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1; m.metallic_specular = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func tinted(c: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(c, a)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.roughness = 0.3
	return m

static func glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c
	m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = 0.8
	return m

static func anim(node: Node3D, d: Dictionary) -> Node3D:
	node.set_meta("anim", d)
	return node

static func star_mesh(r: float, thick: float) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for k in 10:
		var a := -PI / 2 + PI * k / 5.0
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(Vector2(cos(a) * rr, -sin(a) * rr))
	for side in [1.0, -1.0]:
		for k in 10:
			var a: Vector2 = pts[k]; var b: Vector2 = pts[(k + 1) % 10]
			var tip := Vector3(0, 0, thick * side)
			if side > 0:
				st.add_vertex(tip); st.add_vertex(Vector3(b.x, b.y, 0)); st.add_vertex(Vector3(a.x, a.y, 0))
			else:
				st.add_vertex(tip); st.add_vertex(Vector3(a.x, a.y, 0)); st.add_vertex(Vector3(b.x, b.y, 0))
	st.generate_normals()
	return st.commit()

static func star(n: Node3D, pos: Vector3, r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = star_mesh(r, r * 0.35)
	mi.position = pos; mi.material_override = glow(c); n.add_child(mi)
	return mi

static func fish(n: Node3D, c: Color, size: float) -> Node3D:
	var f := Node3D.new(); n.add_child(f)
	Yarn.ball(f, Vector3.ZERO, Vector3(0.5, 0.6, 1.0) * size, c)
	var tail := Yarn.cyl(f, Vector3(0, 0, -0.55 * size), 0.0, 0.3 * size, 0.35 * size, c.darkened(0.1), true, Vector3(PI / 2, 0, 0))
	tail.scale = Vector3(0.3, 1, 1)
	for s in [-1, 1]:
		Yarn.ball(f, Vector3(0.18 * s * size, 0.08 * size, 0.28 * size), Vector3(0.12, 0.12, 0.08) * size, Color.WHITE, false)
		Yarn.ball(f, Vector3(0.2 * s * size, 0.08 * size, 0.31 * size), Vector3(0.07, 0.07, 0.05) * size, Color("231c2a"), false)
	return f

static func build(n: Node3D, id: String) -> bool:
	var wood := Color("b5784a")
	match id:
		# ---------- zvířátka ----------
		"akvarko":
			Yarn.box(n, Vector3(0, 0.2, 0), Vector3(0.62, 0.4, 0.36), Color("8a6a50"))
			var water := MeshInstance3D.new(); var wb := BoxMesh.new(); wb.size = Vector3(0.56, 0.3, 0.3)
			water.mesh = wb; water.position = Vector3(0, 0.56, 0); water.material_override = tinted(Color("5cc8ff"), 0.35); n.add_child(water)
			var gl := MeshInstance3D.new(); var gb := BoxMesh.new(); gb.size = Vector3(0.6, 0.36, 0.34)
			gl.mesh = gb; gl.position = Vector3(0, 0.58, 0); gl.material_override = glass(); n.add_child(gl)
			Yarn.box(n, Vector3(0, 0.43, 0), Vector3(0.56, 0.04, 0.3), Color("f2dca0"))
			for p in [Vector3(-0.18, 0.5, -0.06), Vector3(0.2, 0.52, 0.05), Vector3(-0.05, 0.48, 0.08)]:
				Yarn.ball(n, p, Vector3(0.05, 0.14, 0.05), Color("4fbf6e"))
			Yarn.ball(n, Vector3(0.1, 0.46, -0.08), Vector3(0.09, 0.05, 0.07), Color("b8b0a8"))
			anim(fish(n, Color("ff8a3c"), 0.09), {"k": "fish", "c": Vector3(0, 0.58, 0), "rx": 0.18, "rz": 0.07, "sp": 1.2, "ph": 0.0})
			anim(fish(n, Color("ffc93c"), 0.07), {"k": "fish", "c": Vector3(0, 0.63, 0), "rx": 0.15, "rz": 0.06, "sp": -1.6, "ph": 2.0})
			anim(fish(n, Color("9b7cff"), 0.06), {"k": "fish", "c": Vector3(0, 0.53, 0), "rx": 0.2, "rz": 0.05, "sp": 0.9, "ph": 4.0})
			for k in 3:
				anim(Yarn.ball(n, Vector3(0.2, 0.48, 0), Vector3(0.025, 0.025, 0.025), Color(1, 1, 1), false), {"k": "bubble", "x": 0.2 - k * 0.01, "ph": k * 0.33})
		"kulate":
			Yarn.cyl(n, Vector3(0, 0.03, 0), 0.15, 0.17, 0.06, wood)
			var w := Yarn.ball(n, Vector3(0, 0.2, 0), Vector3(0.3, 0.26, 0.3), Color("5cc8ff"))
			w.material_override = tinted(Color("5cc8ff"), 0.35)
			var g := Yarn.ball(n, Vector3(0, 0.22, 0), Vector3(0.34, 0.32, 0.34), Color.WHITE)
			g.material_override = glass()
			Yarn.ball(n, Vector3(0, 0.08, 0), Vector3(0.2, 0.04, 0.2), Color("f2dca0"))
			anim(fish(n, Color("ff8a3c"), 0.08), {"k": "fish", "c": Vector3(0, 0.2, 0), "rx": 0.07, "rz": 0.07, "sp": 1.4, "ph": 0.0})
		"terarko":
			Yarn.box(n, Vector3(0, 0.15, 0), Vector3(0.62, 0.3, 0.38), wood)
			Yarn.box(n, Vector3(0, 0.33, 0), Vector3(0.56, 0.06, 0.32), Color("d9b380"))
			for p in [Vector3(0.16, 0.38, -0.06), Vector3(-0.2, 0.37, 0.08)]:
				Yarn.ball(n, p, Vector3(0.12, 0.07, 0.1), Color("c79a62"))
			Yarn.ball(n, Vector3(-0.15, 0.4, -0.1), Vector3(0.05, 0.12, 0.05), Color("4fbf6e"))
			var gl := MeshInstance3D.new(); var gb := BoxMesh.new(); gb.size = Vector3(0.6, 0.34, 0.36)
			gl.mesh = gb; gl.position = Vector3(0, 0.47, 0); gl.material_override = glass(); n.add_child(gl)
			Yarn.box(n, Vector3(0, 0.645, 0), Vector3(0.62, 0.015, 0.38), Color(0.3, 0.3, 0.3))
			for k in 7:
				var ant := Node3D.new(); n.add_child(ant)
				for b in 3:
					Yarn.ball(ant, Vector3(0, 0.012, -0.018 + b * 0.018), Vector3(0.016, 0.014, 0.018), Color("2a1a14"), false)
				anim(ant, {"k": "ant", "ph": k / 7.0, "y": 0.36})
		"zelvicka":
			Yarn.box(n, Vector3(0, 0.08, 0), Vector3(0.66, 0.16, 0.44), Color("8ccf7a"))
			Yarn.box(n, Vector3(0, 0.165, 0), Vector3(0.6, 0.02, 0.38), Color("7bbd68"))
			for x in [-0.33, 0.33]:
				Yarn.box(n, Vector3(x, 0.2, 0), Vector3(0.02, 0.1, 0.44), wood)
			for z in [-0.22, 0.22]:
				Yarn.box(n, Vector3(0, 0.2, z), Vector3(0.66, 0.1, 0.02), wood)
			var t := Node3D.new(); n.add_child(t)
			Yarn.ball(t, Vector3(0, 0.22, 0), Vector3(0.16, 0.08, 0.2), Color("5a9a48"))
			Yarn.ball(t, Vector3(0, 0.25, 0), Vector3(0.1, 0.04, 0.12), Color("78b860"))
			Yarn.ball(t, Vector3(0, 0.215, 0.12), Vector3(0.06, 0.05, 0.07), Color("a9d68f"))
			for p in [Vector3(-0.06, 0.19, 0.06), Vector3(0.06, 0.19, 0.06), Vector3(-0.06, 0.19, -0.06), Vector3(0.06, 0.19, -0.06)]:
				Yarn.ball(t, p, Vector3(0.04, 0.03, 0.04), Color("a9d68f"))
			anim(t, {"k": "turtle"})
		# ---------- dobroty ----------
		"dort":
			Yarn.cyl(n, Vector3(0, 0.01, 0), 0.2, 0.2, 0.02, Color.WHITE)
			Yarn.cyl(n, Vector3(0, 0.07, 0), 0.16, 0.16, 0.1, Color("ffd6e0"))
			Yarn.cyl(n, Vector3(0, 0.125, 0), 0.165, 0.165, 0.015, Color("fffaf4"))
			Yarn.cyl(n, Vector3(0, 0.17, 0), 0.11, 0.11, 0.08, Color("ff8ab3"))
			Yarn.cyl(n, Vector3(0, 0.215, 0), 0.115, 0.115, 0.015, Color("fffaf4"))
			for k in 6:
				var a := TAU * k / 6.0
				Yarn.ball(n, Vector3(cos(a) * 0.13, 0.135, sin(a) * 0.13), Vector3(0.035, 0.035, 0.035), Color("ff3b5c"))
			for k in 3:
				var a := TAU * k / 3.0 + 0.5
				var p := Vector3(cos(a) * 0.05, 0.25, sin(a) * 0.05)
				Yarn.cyl(n, p, 0.008, 0.008, 0.07, [Color("6fa8ff"), Color("ffc93c"), Color("5cc6b8")][k], false)
				anim(Yarn.ball(n, p + Vector3(0, 0.045, 0), Vector3(0.016, 0.026, 0.016), Color("ffb020"), false), {"k": "flame"})
		"muffin":
			Yarn.cyl(n, Vector3(0, 0.04, 0), 0.07, 0.055, 0.08, Color("6fa8ff"))
			Yarn.ball(n, Vector3(0, 0.1, 0), Vector3(0.16, 0.1, 0.16), Color("b07040"))
			Yarn.ball(n, Vector3(0, 0.13, 0), Vector3(0.13, 0.07, 0.13), Color("ffd6e0"))
			Yarn.ball(n, Vector3(0, 0.175, 0), Vector3(0.04, 0.04, 0.04), Color("ff3b5c"))
		"koblih":
			var d := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.03; tm.outer_radius = 0.09; tm.rings = 16; tm.ring_segments = 8
			d.mesh = tm; d.position.y = 0.03; d.material_override = Yarn.mat(Color("e0a060")); n.add_child(d)
			var top := MeshInstance3D.new(); var t2 := TorusMesh.new(); t2.inner_radius = 0.035; t2.outer_radius = 0.085; t2.rings = 16; t2.ring_segments = 8
			top.mesh = t2; top.position.y = 0.042; top.scale = Vector3(1, 0.6, 1); top.material_override = Yarn.mat(Color("ff8ab3")); n.add_child(top)
			var cols := [Color("ffc93c"), Color("6fa8ff"), Color.WHITE, Color("5cc6b8")]
			for k in 10:
				var a := TAU * k / 10.0
				Yarn.box(n, Vector3(cos(a) * 0.06, 0.06, sin(a) * 0.06), Vector3(0.012, 0.006, 0.006), cols[k % 4])
		"zmrzlina":
			Yarn.cyl(n, Vector3(0, 0.08, 0), 0.05, 0.0, 0.16, Color("e0a060"), true, Vector3.ZERO)
			Yarn.ball(n, Vector3(0, 0.18, 0), Vector3(0.11, 0.1, 0.11), Color("ffd6e0"))
			Yarn.ball(n, Vector3(0, 0.25, 0), Vector3(0.09, 0.09, 0.09), Color("b0f0d0"))
			Yarn.ball(n, Vector3(0, 0.305, 0), Vector3(0.03, 0.03, 0.03), Color("ff3b5c"))
		"lizatko":
			Yarn.cyl(n, Vector3(0, 0.15, 0), 0.008, 0.008, 0.3, Color.WHITE, false)
			var l := Yarn.cyl(n, Vector3(0, 0.33, 0), 0.08, 0.08, 0.025, Color("ff7ab8"), true, Vector3(PI / 2, 0, 0))
			Yarn.cyl(n, Vector3(0, 0.33, 0.014), 0.05, 0.05, 0.005, Color("fff0f6"), false, Vector3(PI / 2, 0, 0))
			Yarn.cyl(n, Vector3(0, 0.33, 0.017), 0.025, 0.025, 0.005, Color("ff7ab8"), false, Vector3(PI / 2, 0, 0))
			Yarn.cyl(n, Vector3(0, 0.02, 0), 0.06, 0.07, 0.04, Color("9b7cff"))
		"bonbony":
			Yarn.cyl(n, Vector3(0, 0.05, 0), 0.14, 0.09, 0.1, Color("bfe6ff"))
			var cols := [Color("ff3b5c"), Color("ffc93c"), Color("4fbf6e"), Color("6fa8ff"), Color("ff7ab8"), Color("9b7cff")]
			for k in 14:
				var a := TAU * k / 7.0
				var r := 0.04 if k < 7 else 0.09
				Yarn.ball(n, Vector3(cos(a) * r, 0.11 + (k % 3) * 0.015, sin(a) * r), Vector3(0.05, 0.05, 0.05), cols[k % 6])
		"susenky":
			Yarn.cyl(n, Vector3(0, 0.01, 0), 0.15, 0.15, 0.02, Color.WHITE)
			for k in 5:
				var a := TAU * k / 5.0
				var p := Vector3(cos(a) * 0.07, 0.03 + (k % 2) * 0.012, sin(a) * 0.07)
				Yarn.cyl(n, p, 0.05, 0.05, 0.015, Color("d9a060"))
				for c in 3:
					Yarn.ball(n, p + Vector3(cos(c * 2.1) * 0.025, 0.009, sin(c * 2.1) * 0.025), Vector3(0.012, 0.008, 0.012), Color("5a3020"), false)
		"palacinky":
			Yarn.cyl(n, Vector3(0, 0.01, 0), 0.15, 0.15, 0.02, Color.WHITE)
			for k in 5:
				Yarn.cyl(n, Vector3(0, 0.03 + k * 0.022, 0), 0.1 - k * 0.003, 0.1, 0.02, Color("eeb870"))
			Yarn.ball(n, Vector3(0, 0.14, 0), Vector3(0.12, 0.025, 0.12), Color("c06020"))
			for p in [Vector3(0.03, 0.155, 0.02), Vector3(-0.03, 0.155, -0.01), Vector3(0.0, 0.16, -0.04)]:
				Yarn.ball(n, p, Vector3(0.035, 0.03, 0.035), Color("ff3b5c"))
		# ---------- ovoce a zelenina ----------
		"jablko":
			Yarn.ball(n, Vector3(0, 0.07, 0), Vector3(0.14, 0.13, 0.14), Color("ff4d4d"))
			Yarn.cyl(n, Vector3(0, 0.15, 0), 0.006, 0.006, 0.04, Color("6a4020"), false)
			Yarn.ball(n, Vector3(0.025, 0.16, 0), Vector3(0.04, 0.012, 0.025), Color("4fbf6e"), true, Vector3(0, 0, 0.4))
		"hruska":
			Yarn.lathe(n, [Vector2(0, 0), Vector2(0.05, 0.01), Vector2(0.07, 0.05), Vector2(0.06, 0.1), Vector2(0.035, 0.14), Vector2(0.025, 0.17), Vector2(0, 0.18)], Vector3.ZERO, Color("c8e05a"))
			Yarn.cyl(n, Vector3(0, 0.195, 0), 0.006, 0.006, 0.035, Color("6a4020"), false)
		"banan":
			for k in 3:
				var bn := Node3D.new(); bn.rotation.y = (k - 1) * 0.3; n.add_child(bn)
				Yarn.lathe(bn, [Vector2(0, -0.11), Vector2(0.018, -0.1), Vector2(0.028, -0.05), Vector2(0.03, 0.0), Vector2(0.028, 0.05), Vector2(0.018, 0.1), Vector2(0, 0.115)], Vector3(0, 0.035, 0), Color("ffe14d"), true, Vector3(0, 0, PI / 2 - 0.25), 1.0, 12, Vector3(1, 1, 0.9))
				Yarn.ball(bn, Vector3(-0.11, 0.06, 0), Vector3(0.02, 0.02, 0.02), Color("6a4020"), false)
		"jahody":
			Yarn.cyl(n, Vector3(0, 0.04, 0), 0.13, 0.09, 0.08, Color("fff0f6"))
			for k in 8:
				var a := TAU * k / 8.0
				var p := Vector3(cos(a) * 0.06, 0.1, sin(a) * 0.06)
				Yarn.cyl(n, p, 0.03, 0.0, 0.06, Color("ff3b5c"), true, Vector3(PI, 0, 0))
				Yarn.ball(n, p + Vector3(0, 0.032, 0), Vector3(0.04, 0.01, 0.04), Color("4fbf6e"))
		"hrozny":
			var k := 0
			for row in 4:
				for c in 4 - row:
					Yarn.ball(n, Vector3((c - (3 - row) / 2.0) * 0.04, 0.17 - row * 0.035, (k % 2) * 0.02), Vector3(0.045, 0.045, 0.045), Color("8e5ad8"))
					k += 1
			Yarn.cyl(n, Vector3(0, 0.2, 0), 0.006, 0.006, 0.04, Color("6a4020"), false)
			Yarn.ball(n, Vector3(0.03, 0.21, 0), Vector3(0.06, 0.012, 0.04), Color("4fbf6e"))
			Yarn.cyl(n, Vector3(0, 0.01, 0), 0.1, 0.1, 0.02, Color.WHITE)
		"pomeranc":
			Yarn.ball(n, Vector3(0, 0.075, 0), Vector3(0.15, 0.15, 0.15), Color("ff9a1a"))
			Yarn.ball(n, Vector3(0, 0.15, 0), Vector3(0.03, 0.012, 0.02), Color("4fbf6e"))
		"meloun":
			var s := Yarn.cyl(n, Vector3(0, 0.1, 0), 0.0, 0.14, 0.04, Color("ff4d6d"), true, Vector3(PI / 2, 0, 0))
			s.scale = Vector3(1, 1, 1)
			Yarn.box(n, Vector3(0, 0.02, 0), Vector3(0.28, 0.035, 0.05), Color("3a9a48"))
			Yarn.box(n, Vector3(0, 0.045, 0), Vector3(0.26, 0.015, 0.045), Color("e8ffd0"))
			for x in [-0.05, 0.0, 0.05]:
				Yarn.ball(n, Vector3(x, 0.1, 0.022), Vector3(0.012, 0.02, 0.006), Color("231c2a"), false)
		"brokolice":
			Yarn.cyl(n, Vector3(0, 0.05, 0), 0.025, 0.035, 0.1, Color("9fd88a"))
			for p in [Vector3(0, 0.14, 0), Vector3(0.05, 0.12, 0.02), Vector3(-0.05, 0.12, -0.01), Vector3(0.01, 0.12, 0.05), Vector3(-0.01, 0.12, -0.05)]:
				Yarn.ball(n, p, Vector3(0.07, 0.06, 0.07), Color("3a9a48"))
		"okurka":
			Yarn.ball(n, Vector3(0, 0.035, 0), Vector3(0.22, 0.07, 0.07), Color("4fa860"), true, Vector3(0, 0.3, 0))
		"kukurice":
			Yarn.ball(n, Vector3(0, 0.04, 0), Vector3(0.22, 0.08, 0.08), Color("ffd84a"), true, Vector3(0, 0.3, 0))
			for s in [-1, 1]:
				Yarn.ball(n, Vector3(0.03, 0.04, 0.03 * s), Vector3(0.24, 0.03, 0.06), Color("8fd17a"), true, Vector3(0, 0.3 + 0.2 * s, 0))
		"misaovoce":
			Yarn.cyl(n, Vector3(0, 0.05, 0), 0.17, 0.1, 0.1, Color("9fd8ff"))
			Yarn.ball(n, Vector3(-0.05, 0.12, 0.02), Vector3(0.1, 0.1, 0.1), Color("ff4d4d"))
			Yarn.ball(n, Vector3(0.06, 0.12, -0.02), Vector3(0.1, 0.1, 0.1), Color("ff9a1a"))
			Yarn.ball(n, Vector3(0.0, 0.13, 0.07), Vector3(0.09, 0.09, 0.09), Color("c8e05a"))
			Yarn.ball(n, Vector3(0.0, 0.16, -0.05), Vector3(0.07, 0.07, 0.07), Color("8e5ad8"))
		# ---------- dárky a hvězdičky ----------
		"darek1", "darek2", "darek3", "darek4":
			var k := int(id.substr(5)) - 1
			var box_c: Color = [Color("ff8ab3"), Color("6fa8ff"), Color("ffc93c"), Color("5cc6b8")][k]
			var rib: Color = [Color("ffe14d"), Color("ff5d73"), Color("9b7cff"), Color("fff0f6")][k]
			var sz: float = [0.24, 0.18, 0.3, 0.2][k]
			Yarn.box(n, Vector3(0, sz * 0.4, 0), Vector3(sz, sz * 0.8, sz), box_c)
			Yarn.box(n, Vector3(0, sz * 0.4, 0), Vector3(sz * 1.01, sz * 0.8, sz * 0.18), rib)
			Yarn.box(n, Vector3(0, sz * 0.4, 0), Vector3(sz * 0.18, sz * 0.8, sz * 1.01), rib)
			var lid := Node3D.new(); lid.name = "lid"; lid.position.y = sz * 0.8; n.add_child(lid)
			Yarn.box(lid, Vector3(0, sz * 0.07, 0), Vector3(sz * 1.08, sz * 0.14, sz * 1.08), box_c.lightened(0.1))
			Yarn.box(lid, Vector3(0, sz * 0.07, 0), Vector3(sz * 1.09, sz * 0.15, sz * 0.18), rib)
			for s in [-1, 1]:
				Yarn.ball(lid, Vector3(sz * 0.12 * s, sz * 0.22, 0), Vector3(sz * 0.3, sz * 0.18, sz * 0.12), rib, true, Vector3(0, 0, 0.4 * s))
			Yarn.ball(lid, Vector3(0, sz * 0.2, 0), Vector3(sz * 0.12, sz * 0.12, sz * 0.12), rib.darkened(0.1))
			var surprise := star(lid, Vector3(0, -sz * 0.3, 0), sz * 0.3, Color("ffd84a"))
			surprise.name = "surprise"; surprise.visible = false
		"hvezdicka":
			Yarn.cyl(n, Vector3(0, 0.01, 0), 0.08, 0.09, 0.02, Color("9b7cff"))
			anim(star(n, Vector3(0, 0.35, 0), 0.12, Color("ffd84a")), {"k": "spin", "y": 0.35})
			for k in 4:
				anim(star(n, Vector3(0, 0.35, 0), 0.03, Color("fff3a0")), {"k": "orbit", "y": 0.35, "ph": k * TAU / 4.0})
		"hvezdy":
			for k in 5:
				var a := TAU * k / 5.0
				anim(star(n, Vector3(cos(a) * 0.15, 0.06, sin(a) * 0.15), [0.05, 0.07, 0.045, 0.06, 0.055][k], [Color("ffd84a"), Color("ff8ab3"), Color("6fa8ff"), Color("5cc6b8"), Color("ffb020")][k]), {"k": "twinkle", "ph": k})
		"hvezdnalampa":
			Yarn.cyl(n, Vector3(0, 0.02, 0), 0.1, 0.12, 0.04, Color("9b7cff"))
			Yarn.cyl(n, Vector3(0, 0.12, 0), 0.012, 0.012, 0.2, Color("cdbcff"), false)
			star(n, Vector3(0, 0.33, 0), 0.13, Color("ffe14d"))
		"balonky":
			var cols := [Color("ff5d73"), Color("6fa8ff"), Color("ffc93c"), Color("5cc6b8"), Color("ff8ab3")]
			Yarn.box(n, Vector3(0, 0.02, 0), Vector3(0.08, 0.04, 0.08), Color("9b7cff"))
			for k in 5:
				var b := Node3D.new(); n.add_child(b)
				var top := Vector3(cos(k * 1.3) * 0.12, 0.95 + (k % 3) * 0.1, sin(k * 1.3) * 0.12)
				var mid := top * 0.5
				var str_mi := Yarn.cyl(b, mid + Vector3(0, 0.02, 0), 0.003, 0.003, top.length(), Color.WHITE, false)
				str_mi.basis = Basis(Quaternion(Vector3.UP, top.normalized()))
				Yarn.lathe(b, [Vector2(0, -0.13), Vector2(0.06, -0.11), Vector2(0.1, -0.03), Vector2(0.1, 0.04), Vector2(0.07, 0.1), Vector2(0, 0.12)], top + Vector3(0, 0.13, 0), cols[k])
				anim(b, {"k": "sway", "ph": k})
		"srdicko":
			for s in [-1, 1]:
				Yarn.ball(n, Vector3(0.055 * s, 0.2, 0), Vector3(0.14, 0.14, 0.09), Color("ff5d73"))
			var bx := Yarn.box(n, Vector3(0, 0.135, 0), Vector3(0.14, 0.14, 0.085), Color("ff5d73"), true)
			bx.rotation.z = PI / 4
		# ---------- péče a návyky ----------
		"kartacek":
			Yarn.cyl(n, Vector3(0, 0.05, 0), 0.04, 0.035, 0.1, Color("6fa8ff"))
			var b := Node3D.new(); b.position = Vector3(0.0, 0.05, 0); b.rotation.z = 0.2; n.add_child(b)
			Yarn.cyl(b, Vector3(0, 0.1, 0), 0.008, 0.008, 0.2, Color("5cc6b8"), false)
			Yarn.box(b, Vector3(0, 0.2, 0.012), Vector3(0.016, 0.035, 0.016), Color.WHITE)
			var p := Node3D.new(); p.position = Vector3(0.09, 0.015, 0.02); p.rotation.y = 0.4; n.add_child(p)
			Yarn.ball(p, Vector3(0, 0, 0), Vector3(0.05, 0.03, 0.14), Color("fff0f6"), true)
			Yarn.cyl(p, Vector3(0, 0, 0.075), 0.012, 0.012, 0.02, Color("ff5d73"), false, Vector3(PI / 2, 0, 0))
			Yarn.box(p, Vector3(0, 0.014, -0.01), Vector3(0.03, 0.004, 0.05), Color("6fa8ff"))
		"umyvadlo":
			Yarn.box(n, Vector3(0, 0.17, 0), Vector3(0.2, 0.34, 0.2), Color("f6f2ff"))
			Yarn.box(n, Vector3(0, 0.36, 0), Vector3(0.5, 0.06, 0.36), Color.WHITE)
			Yarn.box(n, Vector3(0, 0.38, 0.02), Vector3(0.36, 0.03, 0.24), Color("bfe6ff"))
			Yarn.cyl(n, Vector3(0, 0.44, -0.12), 0.015, 0.015, 0.12, Color("cdd6e0"), false)
			Yarn.box(n, Vector3(0, 0.49, -0.08), Vector3(0.025, 0.025, 0.09), Color("cdd6e0"))
			Yarn.box(n, Vector3(0, 0.72, -0.17), Vector3(0.36, 0.4, 0.02), Color("e8f6ff"))
			Yarn.box(n, Vector3(0, 0.72, -0.18), Vector3(0.4, 0.44, 0.015), Color("ff8ab3"))
			Yarn.ball(n, Vector3(0.18, 0.4, 0.08), Vector3(0.06, 0.035, 0.04), Color("ffc93c"))
		"mydlo":
			Yarn.ball(n, Vector3(0, 0.015, 0), Vector3(0.14, 0.03, 0.1), Color("6fa8ff"))
			Yarn.ball(n, Vector3(0, 0.04, 0), Vector3(0.09, 0.035, 0.06), Color("ffd6e0"))
			for k in 3:
				anim(Yarn.ball(n, Vector3(0, 0.06, 0), Vector3(0.025, 0.025, 0.025), Color(1, 1, 1), false), {"k": "bubble", "x": -0.02 + k * 0.02, "ph": k * 0.33, "h": 0.15, "base": 0.06})
		"rucnik":
			Yarn.cyl(n, Vector3(-0.16, 0.25, 0), 0.012, 0.012, 0.5, Color("cdd6e0"), false)
			Yarn.cyl(n, Vector3(0.16, 0.25, 0), 0.012, 0.012, 0.5, Color("cdd6e0"), false)
			Yarn.cyl(n, Vector3(0, 0.48, 0), 0.012, 0.012, 0.34, Color("cdd6e0"), false, Vector3(0, 0, PI / 2))
			Yarn.box(n, Vector3(0, 0.36, 0.02), Vector3(0.28, 0.26, 0.025), Color("5cc6b8"))
			Yarn.box(n, Vector3(0, 0.36, -0.02), Vector3(0.28, 0.22, 0.025), Color("5cc6b8"))
			Yarn.box(n, Vector3(0, 0.26, 0.034), Vector3(0.28, 0.03, 0.005), Color.WHITE)
			for x in [-0.16, 0.16]: Yarn.box(n, Vector3(x, 0.01, 0), Vector3(0.06, 0.02, 0.16), Color("cdd6e0"))
		"hreben":
			Yarn.box(n, Vector3(0, 0.01, 0), Vector3(0.16, 0.012, 0.04), Color("ff8ab3"))
			for k in 9:
				Yarn.box(n, Vector3(-0.07 + k * 0.016, 0.01, 0.03), Vector3(0.006, 0.01, 0.03), Color("ff8ab3"))
		"zachod":
			Yarn.cyl(n, Vector3(0, 0.08, 0.04), 0.08, 0.06, 0.16, Color.WHITE)
			var seat := Yarn.cyl(n, Vector3(0, 0.17, 0.05), 0.12, 0.12, 0.03, Color.WHITE); seat.scale = Vector3(1, 1, 1.25)
			var hole := Yarn.cyl(n, Vector3(0, 0.186, 0.05), 0.07, 0.07, 0.01, Color("bfe6ff"), false); hole.scale = Vector3(1, 1, 1.25)
			Yarn.box(n, Vector3(0, 0.3, -0.15), Vector3(0.26, 0.28, 0.12), Color.WHITE)
			Yarn.box(n, Vector3(0, 0.45, -0.15), Vector3(0.28, 0.03, 0.14), Color("f6f2ff"))
			Yarn.cyl(n, Vector3(0.08, 0.475, -0.15), 0.025, 0.025, 0.015, Color("cdd6e0"), false)
		"nocnik":
			Yarn.cyl(n, Vector3(0, 0.07, 0), 0.11, 0.09, 0.14, Color("ff8ab3"))
			var rim := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.08; tm.outer_radius = 0.12; tm.rings = 18; tm.ring_segments = 6
			rim.mesh = tm; rim.position.y = 0.14; rim.material_override = Yarn.mat(Color("ffb3d1")); n.add_child(rim)
			Yarn.ball(n, Vector3(0, 0.12, 0.12), Vector3(0.06, 0.06, 0.06), Color("ffc93c"))
		"vana":
			Yarn.box(n, Vector3(0, 0.15, 0), Vector3(1.0, 0.3, 0.55), Color.WHITE)
			Yarn.box(n, Vector3(0, 0.27, 0), Vector3(0.9, 0.04, 0.45), Color("8fd3ff"))
			for k in 9:
				Yarn.ball(n, Vector3(-0.35 + (k % 5) * 0.17, 0.3, -0.12 + (k / 5) * 0.22), Vector3(0.16, 0.08, 0.14), Color("fdfcff"))
			for x in [-0.45, 0.45]:
				for z in [-0.22, 0.22]:
					Yarn.ball(n, Vector3(x, 0.0, z), Vector3(0.06, 0.05, 0.06), Color("ffc93c"))
			Yarn.ball(n, Vector3(0.25, 0.32, 0.1), Vector3(0.07, 0.06, 0.08), Color("ffe14d"))
			Yarn.ball(n, Vector3(0.25, 0.37, 0.12), Vector3(0.045, 0.045, 0.045), Color("ffe14d"))
			Yarn.cyl(n, Vector3(0.25, 0.365, 0.15), 0.01, 0.018, 0.03, Color("ff9a1a"), false, Vector3(PI / 2, 0, 0))
			for k in 5:
				anim(Yarn.ball(n, Vector3(0, 0.3, 0), Vector3(0.04, 0.04, 0.04), Color(1, 1, 1), false), {"k": "bubble", "x": -0.3 + k * 0.15, "ph": k * 0.2, "h": 0.5, "base": 0.3})
		"voda":
			var g := Yarn.cyl(n, Vector3(0, 0.07, 0), 0.05, 0.04, 0.14, Color.WHITE); g.material_override = glass()
			var w := Yarn.cyl(n, Vector3(0, 0.055, 0), 0.045, 0.037, 0.1, Color("5cc8ff")); w.material_override = tinted(Color("5cc8ff"), 0.6)
		"kos":
			Yarn.cyl(n, Vector3(0, 0.14, 0), 0.12, 0.1, 0.28, Color("4fbf6e"))
			Yarn.cyl(n, Vector3(0, 0.29, 0), 0.125, 0.125, 0.025, Color("3a9a48"))
			Yarn.box(n, Vector3(0, 0.14, 0.11), Vector3(0.08, 0.06, 0.01), Color.WHITE)
		"aktovka":
			Yarn.box(n, Vector3(0, 0.16, 0), Vector3(0.3, 0.32, 0.14), Color("6fa8ff"))
			Yarn.box(n, Vector3(0, 0.26, 0.075), Vector3(0.3, 0.14, 0.02), Color("3a8dde"))
			Yarn.box(n, Vector3(0, 0.12, 0.074), Vector3(0.18, 0.1, 0.01), Color("ffc93c"))
			Yarn.ball(n, Vector3(0, 0.25, 0.09), Vector3(0.04, 0.04, 0.02), Color("ff5d73"))
			star(n, Vector3(0, 0.12, 0.082), 0.035, Color("ff8ab3"))
		"pastelky":
			Yarn.box(n, Vector3(0, 0.003, 0), Vector3(0.3, 0.006, 0.22), Color.WHITE)
			Yarn.ball(n, Vector3(-0.05, 0.008, 0.02), Vector3(0.08, 0.002, 0.08), Color("ffc93c"), false)
			Yarn.box(n, Vector3(0.05, 0.008, -0.03), Vector3(0.08, 0.002, 0.012), Color("4fbf6e"))
			var cols := [Color("ff5d73"), Color("ffc93c"), Color("4fbf6e"), Color("6fa8ff"), Color("9b7cff")]
			for k in 5:
				var c := Yarn.cyl(n, Vector3(0.16, 0.012, -0.08 + k * 0.035), 0.009, 0.009, 0.12, cols[k], false, Vector3(0, 0.2 * k, PI / 2))
		"budik":
			Yarn.ball(n, Vector3(0, 0.09, 0), Vector3(0.15, 0.15, 0.08), Color("ff5d73"))
			Yarn.cyl(n, Vector3(0, 0.09, 0.035), 0.06, 0.06, 0.01, Color.WHITE, false, Vector3(PI / 2, 0, 0))
			Yarn.box(n, Vector3(0, 0.11, 0.042), Vector3(0.006, 0.04, 0.004), Color("231c2a"))
			Yarn.box(n, Vector3(0.012, 0.09, 0.042), Vector3(0.025, 0.006, 0.004), Color("231c2a"))
			for s in [-1, 1]:
				Yarn.ball(n, Vector3(0.05 * s, 0.17, 0), Vector3(0.05, 0.04, 0.04), Color("ffc93c"))
				Yarn.cyl(n, Vector3(0.045 * s, 0.012, 0), 0.008, 0.008, 0.03, Color("231c2a"), false)
		_:
			return false
	return true
