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
var ground_base := Color("6fb85e")
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
	scene.add_child(m); return m

const VIEWS := ["ulice", "udoli", "hrad", "more", "hory", "dino", "vesmir"]
var scene: Node3D        # krajina vybraného výhledu
var view := 0
var ground_y := 0.0      # kde je zem (u hradu jsme vysoko ve věži)
var look := Vector3(0, 1.9, -6)

func build() -> void:
	scene = Node3D.new(); add_child(scene)
	for k in 8:
		var cl := Node3D.new(); cl.position = Vector3(-18 + k * 5.0, 7.5 + (k % 3) * 0.8, -16 - (k % 2) * 4)
		for b in [Vector3(0, 0, 0), Vector3(0.9, 0.2, 0), Vector3(-0.9, 0.1, 0), Vector3(0.3, 0.6, 0)]:
			var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.9; sm.height = 1.6
			mi.mesh = sm; mi.position = b; mi.material_override = flat(Color.WHITE); cl.add_child(mi)
		add_child(cl); clouds.append(cl); cl.set_meta("h", 0.0)
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
	set_view(0)
	set_weather(0, false)

## Přepne krajinu za oknem.
func set_view(k: int) -> void:
	undo(); show_all()
	view = clampi(k, 0, VIEWS.size() - 1)
	for c in scene.get_children(): c.free()
	props.clear(); trees.clear(); houses.clear(); lamps.clear(); car = null
	ground_y = 0.0; look = Vector3(0, 1.9, -6)
	ground_mat = StandardMaterial3D.new(); ground_mat.roughness = 1.0
	call("_view_" + VIEWS[view])
	for cl in clouds: props.append(cl)
	set_weather(weather, false)

func _ground(col: Color, y := 0.0, size := Vector3(90, 0.2, 70), z := -12.0) -> void:
	ground_mat.albedo_color = col; ground_base = col
	var g := MeshInstance3D.new(); var gb := BoxMesh.new(); gb.size = size
	g.mesh = gb; g.position = Vector3(0, y - 0.1, z); g.material_override = ground_mat; scene.add_child(g)

func _add(n: Node3D, h: float, small := false) -> Node3D:
	n.set_meta("h", h); n.set_meta("small", small); props.append(n); return n

func _hill(pos: Vector3, size: Vector3, col: Color) -> Node3D:
	var h := Node3D.new(); h.position = pos; scene.add_child(h)
	Yarn.ball(h, Vector3.ZERO, size, col, false)
	return h

func _cone(parent: Node3D, pos: Vector3, r: float, ht: float, col: Color) -> MeshInstance3D:
	return Yarn.cyl(parent, pos + Vector3(0, ht / 2, 0), 0.0, r, ht, col, false)

func _pine(p: Vector3, s := 1.0) -> Node3D:
	var tr := Node3D.new(); tr.position = p; scene.add_child(tr)
	Yarn.cyl(tr, Vector3(0, 0.3 * s, 0), 0.12 * s, 0.15 * s, 0.6 * s, Color("8a5a35"), false)
	for k in 3: _cone(tr, Vector3(0, (0.5 + k * 0.55) * s, 0), (0.9 - k * 0.22) * s, 1.1 * s, Color("3f9a5a").lightened(k * 0.06))
	return tr

func _palm(p: Vector3, s := 1.0) -> Node3D:
	var tr := Node3D.new(); tr.position = p; scene.add_child(tr)
	for k in 6: Yarn.ball(tr, Vector3(k * 0.06 * s, (0.3 + k * 0.5) * s, 0), Vector3(0.28, 0.55, 0.28) * s, Color("b07a4f"), false)
	for a in 6:
		var leaf := Yarn.ball(tr, Vector3(0.36 * s, 3.1 * s, 0), Vector3(1.6, 0.12, 0.45) * s, Color("4fbf6e"), false)
		leaf.position = Vector3(0.36 * s, 3.1 * s, 0) + Vector3(cos(a * TAU / 6), -0.15, sin(a * TAU / 6)) * 0.7 * s
		leaf.rotation = Vector3(0, -a * TAU / 6, -0.35)
	return tr

func _sheep(p: Vector3) -> Node3D:
	var n := Node3D.new(); n.position = p; n.rotation.y = randf_range(-1, 1); scene.add_child(n)
	for b in [Vector3(0, 0.45, 0), Vector3(0.22, 0.5, 0), Vector3(-0.22, 0.5, 0), Vector3(0, 0.62, 0)]:
		Yarn.ball(n, b, Vector3(0.45, 0.4, 0.4), Color("fdfcff"), false)
	Yarn.ball(n, Vector3(0.42, 0.55, 0), Vector3(0.22, 0.24, 0.2), Color("4a3a4a"), false)
	for x in [-0.2, 0.2]:
		for z in [-0.12, 0.12]: Yarn.cyl(n, Vector3(x, 0.15, z), 0.04, 0.04, 0.3, Color("4a3a4a"), false)
	return n

func _view_ulice() -> void:
	_ground(Color("6fb85e"))
	for x in range(-18, 19, 3):
		_model("road_straight", Vector3(x, 0.01, -4.5), 1.5, PI / 2)
	var house_ids := ["building_A", "building_C", "building_B", "building_G", "building_E", "building_A", "building_C", "building_B"]
	for k in house_ids.size():
		var hm := _model(house_ids[k], Vector3(-15.75 + k * 4.5, 0, -10), 2.2)
		_add(hm, 2.5); houses.append(hm)
	for x in [-9.0, -3.0, 3.0, 9.0]:
		_add(_model("streetlight", Vector3(x, 0, -6.6), 2.6), 1.3)
		var l := OmniLight3D.new(); l.position = Vector3(x, 2.3, -6.4); l.light_color = Color("ffd98a")
		l.light_energy = 2.0; l.omni_range = 4.0; l.visible = false; scene.add_child(l); lamps.append(l)
	for x in [-11.0, -6.5, -1.0, 5.5, 11.5]:
		_add(_model("bush", Vector3(x, 0, -7.4), 3.0), 0.6)
	_add(_model("bench", Vector3(1.8, 0, -7.0), 3.5), 0.2)
	_add(_model("firehydrant", Vector3(6.6, 0, -6.6), 3.0), 0.35)
	car = _model("car_taxi", Vector3(-15, 0.1, -3.8), 2.2, PI / 2)
	_fence(Color.WHITE)
	_flowers()
	for p in [Vector3(-4.5, 0, -1.2), Vector3(4.8, 0, -1.8), Vector3(-8.0, 0, -7.6), Vector3(8.5, 0, -8.0)]:
		var tr := _tree(p); _add(tr, 2.0); trees.append(tr)

func _fence(c: Color) -> void:
	for x in range(-8, 9):
		Yarn.box(scene, Vector3(x * 0.6, 0.35, 1.0), Vector3(0.12, 0.7, 0.08), c)
	Yarn.box(scene, Vector3(0, 0.5, 1.0), Vector3(10.0, 0.08, 0.06), c)

func _flowers() -> void:
	var flower_cols := [Color("ff5d73"), Color("ffc93c"), Color("ff8ab3"), Color("9b7cff")]
	for k in 14:
		var fl := Node3D.new(); fl.position = Vector3(-3.6 + k * 0.55, 0, 1.6); scene.add_child(fl)
		Yarn.cyl(fl, Vector3(0, 0.12, 0), 0.015, 0.015, 0.24, Color("4fa860"), false)
		Yarn.ball(fl, Vector3(0, 0.26, 0), Vector3(0.14, 0.12, 0.14), flower_cols[k % 4], false)
		_add(fl, 0.25, true)

## Údolí s řekou, kopci, ovečkami a vesničkou.
func _view_udoli() -> void:
	_ground(Color("86cf6e"))
	for h in [[Vector3(-14, -2, -26), Vector3(26, 12, 14), Color("7cc466")], [Vector3(10, -3, -30), Vector3(34, 14, 16), Color("6db85c")], [Vector3(0, -4, -40), Vector3(60, 16, 20), Color("a7d98a")]]:
		_hill(h[0], h[1], h[2])
	for k in 6:
		var seg := Yarn.box(scene, Vector3(-6 + k * 2.6, 0.02, -6 - k * 3.2), Vector3(2.0, 0.04, 4.4), Color("6fb7ff"))
		seg.rotation.y = 0.5 - (k % 2) * 0.9
	for p in [Vector3(-9, 0, -14), Vector3(-5, 0, -16), Vector3(7, 0, -15)]:
		var hm := _model(["building_A", "building_B", "building_E"].pick_random(), p, 1.2, randf_range(-0.4, 0.4))
		_add(hm, 1.4); houses.append(hm)
	for p in [Vector3(-6, 0, -3), Vector3(6, 0, -4), Vector3(-11, 0, -8), Vector3(11, 0, -9), Vector3(2, 0, -11), Vector3(-2.5, 0, -9)]:
		var tr := _tree(p); _add(tr, 2.0); trees.append(tr)
	for p in [Vector3(-2, 0, -2.5), Vector3(1.5, 0, -3.5), Vector3(4, 0, -2)]:
		_add(_sheep(p), 0.6)
	_fence(Color("b5784a"))
	_flowers()

## Pohled z věže hradu: cimbuří, pod námi údolí, les a další věže.
func _view_hrad() -> void:
	ground_y = -7.0
	look = Vector3(0, -1.5, -9)
	_ground(Color("86cf6e"), -7.0, Vector3(120, 0.2, 90), -25)
	var stone := Color("cfc8d8")
	Yarn.box(scene, Vector3(0, -1.9, -1.5), Vector3(14, 0.5, 0.8), stone)
	for k in 9:
		Yarn.box(scene, Vector3(-4.8 + k * 1.2, -1.45, -1.5), Vector3(0.7, 0.5, 0.8), stone.darkened(0.05))
	Yarn.box(scene, Vector3(0, -5.0, -1.3), Vector3(14, 6.0, 0.4), stone.darkened(0.12))
	var flag := Node3D.new(); flag.position = Vector3(4.2, -1.2, -1.5); scene.add_child(flag)
	Yarn.cyl(flag, Vector3(0, 0.8, 0), 0.03, 0.03, 1.6, Color("8a5a35"), false)
	Yarn.box(flag, Vector3(0.35, 1.4, 0), Vector3(0.7, 0.4, 0.02), Color("ff5d8f"))
	for p in [Vector3(-9, -7, -14), Vector3(8, -7, -16)]:
		var tw := Node3D.new(); tw.position = p; scene.add_child(tw)
		Yarn.cyl(tw, Vector3(0, 4, 0), 1.3, 1.4, 8, stone, false)
		_cone(tw, Vector3(0, 8, 0), 1.7, 3.2, Color("9b7cff"))
		Yarn.box(tw, Vector3(0, 6, 1.32), Vector3(0.5, 0.8, 0.05), Color("6fa8ff"))
		_add(tw, 9.0); houses.append(tw)
	for k in 6:
		var seg := Yarn.box(scene, Vector3(-10 + k * 4.2, -6.97, -18 - k * 3), Vector3(3.0, 0.04, 6.0), Color("6fb7ff"))
		seg.rotation.y = 0.5 - (k % 2) * 0.9
	for k in 18:
		var p := Vector3(-16 + (k % 9) * 4.0 + (k / 9) * 2.0, -7, -12 - (k / 9) * 8 - (k % 3) * 1.5)
		var pn := _pine(p, 1.6); _add(pn, 3.0); trees.append(pn)
	for p in [Vector3(-3, -7, -22), Vector3(1, -7, -24), Vector3(4, -7, -21)]:
		var hm := _model("building_A", p, 2.0, randf_range(-0.5, 0.5)); _add(hm, 2.0); houses.append(hm)

## Mořská pláž: písek, moře, loďka, maják, palmy, hrad z písku.
func _view_more() -> void:
	_ground(Color("e3b86e"), 0.0, Vector3(90, 0.2, 10), 0.0)
	var sea := Yarn.box(scene, Vector3(0, -0.05, -32), Vector3(120, 0.1, 54), Color("4fb0f0"))
	for k in 6:
		Yarn.box(scene, Vector3(randf_range(-10, 10), 0.01, -6 - k * 4), Vector3(randf_range(2, 5), 0.02, 0.15), Color("d8f2ff"))
	var boat := Node3D.new(); boat.position = Vector3(-4, 0, -14); scene.add_child(boat)
	Yarn.box(boat, Vector3(0, 0.25, 0), Vector3(2.2, 0.5, 0.8), Color("ff7a6e"))
	Yarn.cyl(boat, Vector3(0, 1.5, 0), 0.04, 0.04, 2.2, Color("8a5a35"), false)
	var sail := Yarn.cyl(boat, Vector3(0.5, 1.6, 0), 0.0, 0.8, 1.8, Color.WHITE, false); sail.scale = Vector3(1, 1, 0.05)
	_add(boat, 1.5)
	var lh := Node3D.new(); lh.position = Vector3(9, 0, -18); scene.add_child(lh)
	for k in 4: Yarn.cyl(lh, Vector3(0, 0.6 + k * 1.2, 0), 0.7 - k * 0.08, 0.75 - k * 0.08, 1.2, Color.WHITE if k % 2 == 0 else Color("ff5d73"), false)
	Yarn.cyl(lh, Vector3(0, 5.2, 0), 0.5, 0.5, 0.8, Color("ffe14d"), false)
	_cone(lh, Vector3(0, 5.6, 0), 0.7, 0.9, Color("ff5d73"))
	_add(lh, 6.0); houses.append(lh)
	var isl := _hill(Vector3(3, -0.6, -26), Vector3(9, 2.4, 5), Color("f4dca0")); _add(isl, 0.5)
	var ip := _palm(Vector3(3, 0.4, -26), 1.2); _add(ip, 3.5); trees.append(ip)
	for p in [Vector3(-6.5, 0, -2), Vector3(6.5, 0, -1.5)]:
		var pl := _palm(p); _add(pl, 3.5); trees.append(pl)
	var sc := Node3D.new(); sc.position = Vector3(1.5, 0, -1.2); scene.add_child(sc)
	Yarn.box(sc, Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.9), Color("e8c88a"))
	for x in [-0.45, 0.45]:
		for z in [-0.45, 0.45]:
			Yarn.cyl(sc, Vector3(x, 0.45, z), 0.15, 0.17, 0.9, Color("e8c88a"), false)
			_cone(sc, Vector3(x, 0.9, z), 0.2, 0.3, Color("e8c88a"))
	_add(sc, 0.8)
	var um := Node3D.new(); um.position = Vector3(-2.5, 0, -0.5); scene.add_child(um)
	Yarn.cyl(um, Vector3(0, 0.9, 0), 0.03, 0.03, 1.8, Color.WHITE, false)
	_cone(um, Vector3(0, 1.6, 0), 1.0, 0.45, Color("ff8ab3"))
	_add(um, 1.8)

## Zasněžené hory, jezero, chaloupka a jedličky.
func _view_hory() -> void:
	_ground(Color("d4e4f7"))
	for m in [[Vector3(-12, 0, -32), 9.0, 14.0], [Vector3(0, 0, -38), 12.0, 18.0], [Vector3(13, 0, -30), 8.0, 12.0], [Vector3(-24, 0, -36), 10.0, 13.0]]:
		var mo := Node3D.new(); mo.position = m[0]; scene.add_child(mo)
		_cone(mo, Vector3.ZERO, m[1], m[2], Color("9aa8c4"))
		_cone(mo, Vector3(0, m[2] * 0.62, 0), m[1] * 0.4, m[2] * 0.38, Color.WHITE)
		_add(mo, m[2])
	var lake := Yarn.ball(scene, Vector3(2, 0.01, -12), Vector3(12, 0.05, 5), Color("8fd3ff"), false)
	var cab := Node3D.new(); cab.position = Vector3(-5, 0, -8); scene.add_child(cab)
	Yarn.box(cab, Vector3(0, 0.8, 0), Vector3(2.4, 1.6, 1.8), Color("b5784a"))
	for s in [-1, 1]:
		var rf := Yarn.box(cab, Vector3(0.62 * s, 1.95, 0), Vector3(1.55, 0.15, 2.1), Color.WHITE); rf.rotation.z = -0.6 * s
	Yarn.box(cab, Vector3(0.5, 0.9, 0.91), Vector3(0.45, 0.45, 0.02), Color("ffd98a"))
	_add(cab, 2.0); houses.append(cab)
	for p in [Vector3(-9, 0, -6), Vector3(-2, 0, -4), Vector3(5, 0, -5), Vector3(9, 0, -9), Vector3(-12, 0, -12), Vector3(12, 0, -14), Vector3(-7, 0, -16)]:
		var pn := _pine(p, 1.3); _add(pn, 2.6); trees.append(pn)
	var sm := Node3D.new(); sm.position = Vector3(2.5, 0, -2); scene.add_child(sm)
	for b in [[0.3, 0.6], [0.8, 0.42], [1.18, 0.3]]: Yarn.ball(sm, Vector3(0, b[0], 0), Vector3.ONE * b[1], Color.WHITE, false)
	Yarn.cyl(sm, Vector3(0, 1.18, 0.17), 0.0, 0.03, 0.14, Color("ff9a1a"), false, Vector3(PI / 2, 0, 0))
	_add(sm, 1.3)

## Údolí dinosaurů: sopka, palmy, kapradí a velcí hodní dinosauři.
func _view_dino() -> void:
	_ground(Color("8fcf6a"))
	var vol := Node3D.new(); vol.position = Vector3(6, 0, -30); scene.add_child(vol)
	Yarn.cyl(vol, Vector3(0, 5, 0), 2.0, 10, 10, Color("a07860"), false)
	Yarn.cyl(vol, Vector3(0, 10.05, 0), 1.9, 1.9, 0.1, Color("ff7a3c"), false)
	for k in 4: Yarn.ball(vol, Vector3(k * 0.6, 11.5 + k * 1.4, 0), Vector3.ONE * (1.6 + k * 0.5), Color("e8e2dc"), false)
	_add(vol, 10.0); houses.append(vol)
	_hill(Vector3(-14, -2, -24), Vector3(26, 9, 12), Color("7cc466"))
	for p in [Vector3(-7, 0, -6), Vector3(7, 0, -5), Vector3(-11, 0, -14), Vector3(10, 0, -16), Vector3(-2, 0, -18)]:
		var pl := _palm(p, 1.2); _add(pl, 3.5); trees.append(pl)
	for d in [["dino1", Vector3(-3, 0, -7), 6.0, 0.6], ["dino2", Vector3(3.5, 0, -10), 7.0, -0.9], ["dino1", Vector3(-8.5, 0, -12), 5.0, 1.2]]:
		var dn := Node3D.new(); dn.position = d[1]; dn.rotation.y = d[3]; scene.add_child(dn)
		Props.build(dn, d[0]); dn.scale = Vector3.ONE * d[2]
		_add(dn, 2.0)
	for k in 8:
		var fern := Yarn.ball(scene, Vector3(-6 + k * 1.7, 0.2, -2.5 - (k % 3)), Vector3(0.9, 0.4, 0.7), Color("4fa860"), false)
		_add(fern, 0.3, true)
	for p in [Vector3(0.5, 0, -2), Vector3(1.0, 0, -2.3)]:
		_add(Yarn.ball(scene, p + Vector3(0, 0.2, 0), Vector3(0.3, 0.4, 0.3), Color("fff8e8"), false), 0.4, true)

## Vesmír: měsíční povrch, Země, planety s prstenci, raketa.
func _view_vesmir() -> void:
	_ground(Color("8f8ba8"))
	for k in 7:
		var cr := Yarn.cyl(scene, Vector3(-8 + k * 2.8, 0.02, -3 - (k % 3) * 3), 0.6 + (k % 2) * 0.4, 0.8 + (k % 2) * 0.4, 0.06, Color("9c9ab0"), false)
		_add(cr, 0.1, true)
	var earth := _disc(Vector3(-7, 9, -28), 3.0, Color("5fa8ff")); _add(earth, 0.0)
	Yarn.ball(scene, Vector3(-7.8, 9.8, -25.4), Vector3(1.8, 1.2, 0.5), Color("6fcf6a"), false)
	var pl := Node3D.new(); pl.position = Vector3(9, 7, -26); scene.add_child(pl)
	Yarn.ball(pl, Vector3.ZERO, Vector3.ONE * 4.0, Color("ffb07a"), false)
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 2.6; tm.outer_radius = 3.2
	ring.mesh = tm; ring.rotation = Vector3(0.3, 0, 0.2); ring.material_override = flat(Color("ffe1a8")); pl.add_child(ring)
	_add(pl, 0.0)
	var r := Node3D.new(); r.position = Vector3(4, 0, -8); scene.add_child(r)
	Yarn.cyl(r, Vector3(0, 2.0, 0), 0.6, 0.6, 3.0, Color.WHITE, false)
	_cone(r, Vector3(0, 3.5, 0), 0.6, 1.4, Color("ff5d73"))
	Yarn.cyl(r, Vector3(0, 2.6, 0.58), 0.25, 0.25, 0.05, Color("6fc8ff"), false, Vector3(PI / 2, 0, 0))
	for s in [-1, 1]:
		var fin := Yarn.box(r, Vector3(0.7 * s, 0.7, 0), Vector3(0.5, 1.2, 0.1), Color("ff5d73")); fin.rotation.z = 0.3 * s
	_add(r, 4.0); houses.append(r)
	var flag := Node3D.new(); flag.position = Vector3(-3, 0, -5); scene.add_child(flag)
	Yarn.cyl(flag, Vector3(0, 0.8, 0), 0.03, 0.03, 1.6, Color.WHITE, false)
	Yarn.box(flag, Vector3(0.35, 1.4, 0), Vector3(0.7, 0.45, 0.02), Color("ffc93c"))
	_add(flag, 1.6)

func _tree(p: Vector3) -> Node3D:
	var tr := Node3D.new(); tr.position = p; scene.add_child(tr)
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
	if VIEWS[view] == "vesmir":
		# ve vesmíru neprší ani nesněží, hvězdy svítí pořád
		rain.emitting = false; snow.emitting = false; leaves.emitting = false
		stars.visible = true; moon.visible = false; sun_disk.visible = true; rainbow.visible = false
		for cl in clouds: cl.visible = false
		if in_window: apply_sky()
		return
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
	env.background_color = sky[weather] if VIEWS[view] != "vesmir" else Color("1a1840")
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
	if car and not frozen: car.position.x += d * 2.5
	if car and car.position.x > 18: car.position.x = -18
	snow_k = clampf(snow_k + d * (0.08 if weather == 2 else -0.15), 0.0, 1.0)
	ground_mat.albedo_color = ground_base.lerp(Color("f4f8ff"), snow_k)
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
		var g = Plane(Vector3.UP, global_position.y + ground_y).intersects_ray(o, dir)
		if g != null:
			var local: Vector3 = g - global_position
			if local.z > -7.2 + ground_y * 2.0 and local.z < 3.2 and abs(local.x) < 14:
				var n := _prop(GROUND_PROPS.pick_random(), big)
				n.position = local
				_undo.append(["spawn", n])
				return true
		var s = Plane(Vector3(0, 0, 1), global_position.z - 6.0).intersects_ray(o, dir)
		if s != null:
			var local: Vector3 = s - global_position
			if local.y > 1.6 + ground_y * 0.3 and local.y < 9:
				var n := _prop(SKY_PROPS.pick_random(), big)
				n.position = local
				_undo.append(["spawn", n])
				return true
	return false

## Věcičky, které se objeví za oknem.
func _prop(kind: String, k: float) -> Node3D:
	var n := Node3D.new(); scene.add_child(n)
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
