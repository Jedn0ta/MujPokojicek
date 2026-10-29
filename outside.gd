extends Node3D
## Výhled z okna: ulice s domky (KayKit City, CC0), stromy, mraky a počasí.
## Leží daleko od pokoje (main.gd ji posune), kamera se sem přepne při koukání z okna.

var env: Environment
var sun: DirectionalLight3D
var weather := 0
var t := 0.0
var clouds: Array = []
var trees: Array = []
var lamps: Array = []
var car: Node3D
var rain: CPUParticles3D
var snow: CPUParticles3D
var leaves: CPUParticles3D
var stars: Node3D
var moon: MeshInstance3D
var sun_disk: MeshInstance3D
var rainbow: Node3D
var ground_mat: StandardMaterial3D
var snow_k := 0.0   # kolik je napadáno
var frozen := false  # během minihry se auto a mraky nehýbou
var houses: Array = []
var props: Array = []   # vše, co může zmizet nebo změnit barvu
var _undo: Array = []   # jak vrátit poslední změnu

# výchozí světlo v pokoji, aby se po návratu od okna vrátilo
var room_env := {"bg": Color("ffe9f3"), "amb": 0.45, "sun": 0.25}

static func flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _model(file: String, pos: Vector3, sc: float, rot := 0.0) -> Node3D:
	var m: Node3D = load("res://models/city/%s.gltf" % file).instantiate()
	m.position = pos; m.scale = Vector3.ONE * sc; m.rotation.y = rot
	add_child(m); return m

func build() -> void:
	ground_mat = StandardMaterial3D.new(); ground_mat.albedo_color = Color("6fb85e"); ground_mat.roughness = 1.0
	var g := MeshInstance3D.new(); var gb := BoxMesh.new(); gb.size = Vector3(80, 0.2, 60)
	g.mesh = gb; g.position = Vector3(0, -0.1, -10); g.material_override = ground_mat; add_child(g)
	for x in range(-18, 19, 3):
		_model("road_straight", Vector3(x, 0.01, -4.5), 1.5, PI / 2)
	var house_ids := ["building_A", "building_C", "building_B", "building_G", "building_E", "building_A", "building_C", "building_B"]
	for k in house_ids.size():
		var hm := _model(house_ids[k], Vector3(-15.75 + k * 4.5, 0, -10), 2.2)
		hm.set_meta("h", 2.5); props.append(hm); houses.append(hm)
	for x in [-9.0, -3.0, 3.0, 9.0]:
		var sl := _model("streetlight", Vector3(x, 0, -6.6), 2.6); sl.set_meta("h", 1.3); props.append(sl)
		var l := OmniLight3D.new(); l.position = Vector3(x, 2.3, -6.4); l.light_color = Color("ffd98a")
		l.light_energy = 2.0; l.omni_range = 4.0; l.visible = false; add_child(l); lamps.append(l)
	for x in [-11.0, -6.5, -1.0, 5.5, 11.5]:
		var bu := _model("bush", Vector3(x, 0, -7.4), 3.0); bu.set_meta("h", 0.6); props.append(bu)
	var be := _model("bench", Vector3(1.8, 0, -7.0), 3.5); be.set_meta("h", 0.2); props.append(be)
	var fh := _model("firehydrant", Vector3(6.6, 0, -6.6), 3.0); fh.set_meta("h", 0.35); props.append(fh)
	car = _model("car_taxi", Vector3(-15, 0.1, -3.8), 2.2, PI / 2)
	# plot a zahrádka před oknem
	for x in range(-8, 9):
		Yarn.box(self, Vector3(x * 0.6, 0.35, 1.0), Vector3(0.12, 0.7, 0.08), Color.WHITE)
	Yarn.box(self, Vector3(0, 0.5, 1.0), Vector3(10.0, 0.08, 0.06), Color.WHITE)
	var flower_cols := [Color("ff5d73"), Color("ffc93c"), Color("ff8ab3"), Color("9b7cff")]
	for k in 14:
		var fl := Node3D.new(); fl.position = Vector3(-3.6 + k * 0.55, 0, 1.6); add_child(fl)
		Yarn.cyl(fl, Vector3(0, 0.12, 0), 0.015, 0.015, 0.24, Color("4fa860"), false)
		Yarn.ball(fl, Vector3(0, 0.26, 0), Vector3(0.14, 0.12, 0.14), flower_cols[k % 4], false)
		fl.set_meta("h", 0.25); fl.set_meta("small", true); props.append(fl)
	for p in [Vector3(-4.5, 0, -1.2), Vector3(4.8, 0, -1.8), Vector3(-8.0, 0, -7.6), Vector3(8.5, 0, -8.0)]:
		var tr := _tree(p); tr.set_meta("h", 2.0); trees.append(tr); props.append(tr)
	for k in 8:
		var cl := Node3D.new(); cl.position = Vector3(-18 + k * 5.0, 7.5 + (k % 3) * 0.8, -16 - (k % 2) * 4)
		for b in [Vector3(0, 0, 0), Vector3(0.9, 0.2, 0), Vector3(-0.9, 0.1, 0), Vector3(0.3, 0.6, 0)]:
			var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.9; sm.height = 1.6
			mi.mesh = sm; mi.position = b; mi.material_override = flat(Color.WHITE); cl.add_child(mi)
		add_child(cl); clouds.append(cl); cl.set_meta("h", 0.0); props.append(cl)
	sun_disk = _disc(Vector3(9, 11, -30), 1.8, Color("fff3a0"))
	moon = _disc(Vector3(-8, 10, -30), 1.3, Color("fff8d6"))
	stars = Node3D.new(); add_child(stars)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for k in 90:
		var s := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.06; sm.height = 0.12
		s.mesh = sm; s.material_override = flat(Color("fffbe0"))
		s.position = Vector3(rng.randf_range(-30, 30), rng.randf_range(5, 16), -28); stars.add_child(s)
	rainbow = Node3D.new(); rainbow.position = Vector3(-1, 1.5, -22); add_child(rainbow)
	var rc := [Color("ff4d4d"), Color("ff9a3c"), Color("ffe14d"), Color("5fd16a"), Color("4da3ff"), Color("9b6bff")]
	for k in rc.size():
		var tor := MeshInstance3D.new(); var tm := TorusMesh.new()
		tm.inner_radius = 9.0 - k * 0.45; tm.outer_radius = 9.45 - k * 0.45; tm.rings = 48; tm.ring_segments = 6
		tor.mesh = tm; tor.rotation.x = PI / 2
		var m := flat(rc[k]); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color.a = 0.75
		tor.material_override = m; rainbow.add_child(tor)
	rain = _particles(Vector3(0.02, 0.35, 0.02), Color("9fc6ff"), 700, 0.7)
	rain.direction = Vector3(0, -1, 0); rain.initial_velocity_min = 14; rain.initial_velocity_max = 16; rain.gravity = Vector3(0, -20, 0)
	snow = _particles(Vector3(0.09, 0.09, 0.09), Color.WHITE, 500, 7.0, true)
	snow.direction = Vector3(0.2, -1, 0); snow.spread = 30; snow.initial_velocity_min = 0.6; snow.initial_velocity_max = 1.2; snow.gravity = Vector3(0, -0.9, 0)
	leaves = _particles(Vector3(0.18, 0.02, 0.12), Color("f2a33c"), 70, 4.0)
	leaves.position = Vector3(-12, 3, -3); leaves.emission_box_extents = Vector3(0.5, 3, 6)
	leaves.direction = Vector3(1, 0.1, 0); leaves.spread = 15; leaves.initial_velocity_min = 5; leaves.initial_velocity_max = 8
	leaves.gravity = Vector3(0, -0.6, 0); leaves.angular_velocity_min = -300; leaves.angular_velocity_max = 300
	leaves.color_ramp = null
	set_weather(0, false)

func _tree(p: Vector3) -> Node3D:
	var tr := Node3D.new(); tr.position = p; add_child(tr)
	Yarn.cyl(tr, Vector3(0, 0.8, 0), 0.12, 0.18, 1.6, Color("8a5a35"), false)
	for b in [Vector3(0, 2.0, 0), Vector3(0.55, 1.65, 0.1), Vector3(-0.5, 1.7, -0.1), Vector3(0.1, 2.5, 0)]:
		Yarn.ball(tr, b, Vector3(1.3, 1.2, 1.3), Color("57b85e"), false)
	return tr

func _disc(pos: Vector3, r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2
	mi.mesh = sm; mi.position = pos; mi.material_override = flat(c); add_child(mi); return mi

func _particles(size: Vector3, c: Color, amount: int, life: float, round := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	if round:
		var sm := SphereMesh.new(); sm.radius = size.x / 2; sm.height = size.x; sm.radial_segments = 6; sm.rings = 3; p.mesh = sm
	else:
		var bm := BoxMesh.new(); bm.size = size; p.mesh = bm
	var m := flat(c); p.material_override = m
	p.amount = amount; p.lifetime = life; p.preprocess = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14, 0.2, 9)
	p.position = Vector3(0, 9, -3)
	p.emitting = false
	add_child(p); return p

## Změní počasí. in_window = kamera kouká ven, takže se mění i světlo a obloha.
func set_weather(w: int, in_window := true) -> void:
	weather = w
	rain.emitting = w == 1
	snow.emitting = w == 2
	leaves.emitting = w == 3
	stars.visible = w == 4; moon.visible = w == 4
	sun_disk.visible = w in [0, 3, 5]
	rainbow.visible = w == 5
	for l in lamps: l.visible = w == 4
	var cloud_col := Color("8d96a6") if w == 1 else (Color("e8edf5") if w == 2 else (Color("4a5080") if w == 4 else Color.WHITE))
	for cl in clouds:
		cl.visible = w != 4 or cl.get_index() % 2 == 0
		for b in cl.get_children(): b.material_override = flat(cloud_col)
	if in_window: apply_sky()

func apply_sky() -> void:
	var sky := [Color("8fd3ff"), Color("8a96a8"), Color("cfd8e6"), Color("a9dcff"), Color("1d2350"), Color("9fe0ff")]
	var amb := [0.4, 0.38, 0.45, 0.4, 0.22, 0.4]
	var sl := [0.3, 0.05, 0.12, 0.25, 0.03, 0.3]
	env.background_color = sky[weather]
	env.ambient_light_energy = amb[weather]
	env.ambient_light_color = Color("aab8ff") if weather == 4 else Color("fff4fb")
	sun.light_energy = sl[weather]

func restore_room() -> void:
	env.background_color = room_env["bg"]
	env.ambient_light_energy = room_env["amb"]
	env.ambient_light_color = Color("fff4fb")
	sun.light_energy = room_env["sun"]

func _process(d: float) -> void:
	if not visible: return
	t += d
	var windy := weather == 3
	for cl in clouds:
		if frozen: break
		cl.position.x += d * (3.0 if windy else 0.4)
		if cl.position.x > 22: cl.position.x = -22
	for k in trees.size():
		trees[k].rotation.z = sin(t * (3.0 if windy else 1.0) + k) * (0.09 if windy else 0.015)
	if not frozen: car.position.x += d * 2.5
	if car.position.x > 18: car.position.x = -18
	snow_k = clampf(snow_k + d * (0.08 if weather == 2 else -0.15), 0.0, 1.0)
	ground_mat.albedo_color = Color("6fb85e").lerp(Color("f4f8ff"), snow_k)
	if weather == 4:
		for s in stars.get_children():
			s.scale = Vector3.ONE * (0.7 + 0.3 * sin(t * 3.0 + s.position.x))

# ---------- minihra "Co se změnilo?" ----------

## Kolik věcí je za oknem vidět (lehká = málo, těžká = hodně).
const DENSITY := [5, 9, 15, 99]
var _game_hidden: Array = []

func set_density(level: int) -> void:
	show_all()
	var keep: int = DENSITY[clampi(level - 1, 0, 3)]
	# vždy nech domy uprostřed a pár velkých věcí; zbytek schovej
	var order := props.duplicate()
	order.sort_custom(func(a, b): return _priority(a) > _priority(b))
	for k in order.size():
		if k >= keep:
			order[k].visible = false
			_game_hidden.append(order[k])
	for fl in get_children():
		pass

func _priority(n: Node3D) -> float:
	var p := 0.0
	if n in houses: p += 3.0 - abs(n.position.x) * 0.2
	if n in trees: p += 2.5
	if n.get_meta("small", false): p -= 3.0
	if n in clouds: p += 1.0 - abs(n.position.x) * 0.05
	p -= abs(n.position.x) * 0.08
	return p

func show_all() -> void:
	for n in _game_hidden: if is_instance_valid(n): n.visible = true
	_game_hidden.clear()

const GROUND_PROPS := ["kocka", "pejsek", "snehulak", "duch", "dyne", "mic", "zajicek", "darek"]
const SKY_PROPS := ["ptacek", "balonek", "drak", "hvezda", "motylek", "ufo"]

## Vrátí poslední změnu zpátky.
func undo() -> void:
	for u in _undo:
		match u[0]:
			"spawn": if is_instance_valid(u[1]): u[1].queue_free()
			"hide": u[1].visible = true
			"tint":
				for pair in u[1]: pair[0].material_override = pair[1]
	_undo.clear()

## Udělá jednu změnu uvnitř obdélníku tabulky okna (v pixelech kamery).
## level 1–4: čím vyšší, tím menší a nenápadnější změny.
func make_change(cam: Camera3D, pane: Rect2, level: int) -> bool:
	var kinds := ["spawn"]
	if level >= 2: kinds.append("hide")
	if level >= 3: kinds.append("tint")
	kinds.shuffle()
	for k in kinds:
		if k == "spawn" and _try_spawn(cam, pane, level): return true
		if k == "hide" and _try_hide(cam, pane, level): return true
		if k == "tint" and _try_tint(cam, pane, level): return true
	return _try_spawn(cam, pane, level)

func _screen(cam: Camera3D, n: Node3D) -> Vector2:
	var p := n.global_position + Vector3(0, float(n.get_meta("h", 0.5)) * 0.5, 0)
	if cam.is_position_behind(p): return Vector2(-999, -999)
	return cam.unproject_position(p)

func _candidates(cam: Camera3D, pane: Rect2, level: int) -> Array:
	var inner := pane.grow(-pane.size.x * 0.12)
	var out := []
	for n in props:
		if not n.visible or n in _game_hidden: continue
		if n.get_meta("small", false) and level < 4: continue
		if inner.has_point(_screen(cam, n)): out.append(n)
	out.shuffle()
	return out

func _try_hide(cam: Camera3D, pane: Rect2, level: int) -> bool:
	var c := _candidates(cam, pane, level)
	if c.is_empty(): return false
	c[0].visible = false
	_undo.append(["hide", c[0]])
	return true

func _try_tint(cam: Camera3D, pane: Rect2, level: int) -> bool:
	var c := _candidates(cam, pane, level)
	if c.is_empty(): return false
	var n: Node3D = c[0]
	var colors := [Color("ff4d6d"), Color("4da3ff"), Color("ffd84a"), Color("9b6bff"), Color("4fd16a")]
	var target: Color = colors.pick_random()
	var pairs := []
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var orig = mi.material_override
		var base = orig if orig else mi.get_active_material(0)
		if base == null: continue
		var m: StandardMaterial3D = base.duplicate()
		m.albedo_color = m.albedo_color.lerp(target, 0.75 if level < 4 else 0.45)
		mi.material_override = m
		pairs.append([mi, orig])
	if pairs.is_empty(): return false
	_undo.append(["tint", pairs])
	return true

func _try_spawn(cam: Camera3D, pane: Rect2, level: int) -> bool:
	var inner := pane.grow(-pane.size.x * 0.22)
	for attempt in 8:
		var sp := Vector2(randf_range(inner.position.x, inner.end.x), randf_range(inner.position.y, inner.end.y))
		var o := cam.project_ray_origin(sp); var dir := cam.project_ray_normal(sp)
		var big := 1.25 if level <= 1 else (1.0 if level <= 3 else 0.7)
		var g = Plane(Vector3.UP, global_position.y).intersects_ray(o, dir)
		if g != null:
			var local: Vector3 = g - global_position
			if local.z > -7.2 and local.z < 3.2 and abs(local.x) < 14:
				var n := _prop(GROUND_PROPS.pick_random(), big)
				n.position = local
				_undo.append(["spawn", n])
				return true
		var s = Plane(Vector3(0, 0, 1), global_position.z - 6.0).intersects_ray(o, dir)
		if s != null:
			var local: Vector3 = s - global_position
			if local.y > 1.6 and local.y < 9:
				var n := _prop(SKY_PROPS.pick_random(), big)
				n.position = local
				_undo.append(["spawn", n])
				return true
	return false

## Věcičky, které se objeví za oknem.
func _prop(kind: String, k: float) -> Node3D:
	var n := Node3D.new(); add_child(n)
	var p := Node3D.new(); p.scale = Vector3.ONE * k; n.add_child(p)
	var ink := Color("231c2a")
	match kind:
		"kocka", "pejsek", "zajicek":
			var c: Color = {"kocka": Color("ff9a3c"), "pejsek": Color("b98058"), "zajicek": Color("f6f2ff")}[kind]
			Yarn.ball(p, Vector3(0, 0.2, 0), Vector3(0.45, 0.3, 0.3), c)
			Yarn.ball(p, Vector3(0.22, 0.42, 0.05), Vector3(0.28, 0.26, 0.26), c)
			for s in [-1, 1]:
				Yarn.ball(p, Vector3(0.28, 0.45, 0.05 + s * 0.06), Vector3(0.035, 0.04, 0.03), ink, false)
				match kind:
					"kocka": Yarn.cyl(p, Vector3(0.2, 0.58, 0.05 + s * 0.08), 0.0, 0.05, 0.1, c)
					"pejsek": Yarn.ball(p, Vector3(0.16, 0.42, 0.05 + s * 0.14), Vector3(0.08, 0.2, 0.05), c.darkened(0.2))
					"zajicek": Yarn.ball(p, Vector3(0.18, 0.7, 0.05 + s * 0.06), Vector3(0.07, 0.3, 0.05), c)
			Yarn.ball(p, Vector3(-0.25, 0.32, 0), Vector3(0.08, 0.22, 0.08), c, true, Vector3(0, 0, 0.6))
			n.rotation.y = -PI / 2 + randf_range(-0.4, 0.4)
		"snehulak":
			Yarn.ball(p, Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6), Color.WHITE)
			Yarn.ball(p, Vector3(0, 0.78, 0), Vector3(0.42, 0.42, 0.42), Color.WHITE)
			Yarn.ball(p, Vector3(0, 1.12, 0), Vector3(0.3, 0.3, 0.3), Color.WHITE)
			Yarn.cyl(p, Vector3(0, 1.12, 0.17), 0.0, 0.03, 0.12, Color("ff9a1a"), false, Vector3(PI / 2, 0, 0))
			for s in [-1, 1]: Yarn.ball(p, Vector3(0.06 * s, 1.17, 0.13), Vector3(0.04, 0.04, 0.03), ink, false)
			Yarn.cyl(p, Vector3(0, 1.3, 0), 0.12, 0.14, 0.14, Color("ff5d73"))
		"duch":
			Yarn.lathe(p, [Vector2(0.3, 0.2), Vector2(0.3, 0.6), Vector2(0.26, 0.85), Vector2(0.14, 1.0), Vector2(0, 1.04)], Vector3.ZERO, Color("f8f8ff"))
			for s in [-1, 1]: Yarn.ball(p, Vector3(0.1 * s, 0.75, 0.24), Vector3(0.08, 0.11, 0.05), ink, false)
			Yarn.ball(p, Vector3(0, 0.6, 0.26), Vector3(0.08, 0.06, 0.04), ink, false)
			n.position.y = 0.3
		"dyne":
			Yarn.ball(p, Vector3(0, 0.25, 0), Vector3(0.6, 0.45, 0.55), Color("ff8a1a"))
			Yarn.cyl(p, Vector3(0, 0.5, 0), 0.04, 0.05, 0.12, Color("4fa860"))
		"mic":
			Yarn.ball(p, Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), Color("ff5d73"))
			Yarn.cyl(p, Vector3(0, 0.25, 0), 0.255, 0.255, 0.08, Color.WHITE)
		"darek":
			Props.build(p, "darek1"); p.scale *= 2.0
		"ptacek":
			Yarn.ball(p, Vector3.ZERO, Vector3(0.35, 0.28, 0.28), Color("6fa8ff"))
			Yarn.ball(p, Vector3(0.16, 0.1, 0), Vector3(0.18, 0.18, 0.18), Color("6fa8ff"))
			Yarn.cyl(p, Vector3(0.28, 0.1, 0), 0.0, 0.03, 0.08, Color("ffc93c"), false, Vector3(0, 0, -PI / 2))
			Yarn.ball(p, Vector3(0.2, 0.15, 0.08), Vector3(0.03, 0.03, 0.02), ink, false)
			for s in [-1, 1]: Yarn.ball(p, Vector3(-0.02, 0.1, 0.14 * s), Vector3(0.25, 0.04, 0.16), Color("3a8dde"), true, Vector3(0.4 * s, 0, 0))
		"balonek":
			Yarn.lathe(p, [Vector2(0, -0.3), Vector2(0.14, -0.25), Vector2(0.24, -0.05), Vector2(0.24, 0.1), Vector2(0.16, 0.25), Vector2(0, 0.3)], Vector3.ZERO, [Color("ff5d73"), Color("ffc93c"), Color("9b7cff")].pick_random())
			Yarn.cyl(p, Vector3(0, -0.8, 0), 0.008, 0.008, 1.0, Color.WHITE, false)
		"drak":
			var mi := Yarn.box(p, Vector3.ZERO, Vector3(0.6, 0.6, 0.03), Color("ff8ab3"))
			mi.rotation.z = PI / 4
			Yarn.box(p, Vector3(0, 0, 0.02), Vector3(0.05, 0.82, 0.01), Color("ffe14d"))
			for t in 4: Yarn.ball(p, Vector3(0.05 * t, -0.5 - t * 0.2, 0), Vector3(0.1, 0.06, 0.03), Color("6fa8ff"))
		"hvezda":
			Props.star(p, Vector3.ZERO, 0.4, Color("ffd84a"))
		"motylek":
			for s in [-1, 1]:
				Yarn.ball(p, Vector3(0.16 * s, 0.06, 0), Vector3(0.28, 0.24, 0.02), Color("ff8ab3"), false)
				Yarn.ball(p, Vector3(0.12 * s, -0.12, 0), Vector3(0.18, 0.16, 0.02), Color("9b7cff"), false)
			Yarn.ball(p, Vector3.ZERO, Vector3(0.05, 0.3, 0.05), ink, false)
		"ufo":
			Yarn.ball(p, Vector3.ZERO, Vector3(0.9, 0.2, 0.9), Color("cdd6e0"))
			Yarn.ball(p, Vector3(0, 0.12, 0), Vector3(0.4, 0.3, 0.4), Color("a8ffcf"))
			for a in 6: Yarn.ball(p, Vector3(cos(a) * 0.38, -0.03, sin(a) * 0.38), Vector3(0.07, 0.07, 0.07), Color("ffe14d"), false)
	return n
