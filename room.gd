extends Node3D
## 3D pokojíček: podlaha x -3.35..3.35, z -2..2, zadní a levá stěna, okno se záclonkami.
## Věci se berou z katalogu (catalog.gd).

const HALF := Vector2(3.35, 2.0)
const WINDOW := Rect2(-0.35, 0.8, 1.1, 0.8)   # výchozí okno na zadní stěně: x, y, šířka, výška
static var win := WINDOW

## Okno z uloženého pokojíčku, vždy celé na stěně.
static func win_of(r: Dictionary) -> Rect2:
	var a: Array = r.get("win", [WINDOW.position.x, WINDOW.position.y, WINDOW.size.x, WINDOW.size.y])
	var w := clampf(a[2], 0.6, HALF.x * 2 - 0.8); var h := clampf(a[3], 0.5, 1.6)
	var x := clampf(a[0], -HALF.x + 0.35, HALF.x - 0.35 - w); var y := clampf(a[1], 0.25, 2.05 - h)
	return Rect2(x, y, w, h)

var _items: Array = []
var _anims: Array = []   # [uzel, nastavení, výchozí pozice]
var _t := 0.0
static var _scenes := {}
static var _pattern_cache := {}

func build(r: Dictionary, sel: int) -> void:
	win = win_of(r); Interact.win_x = win.get_center().x
	for c in get_children(): c.free()
	_items.clear(); _anims.clear()
	var floor := MeshInstance3D.new(); var fb := BoxMesh.new(); fb.size = Vector3(HALF.x * 2, 0.1, HALF.y * 2)
	floor.mesh = fb; floor.position.y = -0.05
	floor.material_override = pattern_mat(Data.pick(Data.FLOOR, r.get("floor", 0)), int(r.get("floorp", 0)), true)
	add_child(floor)
	var wm: StandardMaterial3D
	if int(r.get("wallp", 0)) >= 5:
		wm = mural_mat(int(r.get("wallp", 0)) - 5)
	elif int(r.get("wallp", 0)) == 4:
		wm = StandardMaterial3D.new(); wm.roughness = 0.9
		wm.albedo_texture = preload("res://pixel_editor.gd").make_texture(r.get("pix", []), Data.pick(Data.WALL, r.get("wall", 0)))
		wm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		wm.uv1_triplanar = true; wm.uv1_scale = Vector3(1.6, 1.6, 1.6)
	else:
		wm = pattern_mat(Data.pick(Data.WALL, r.get("wall", 0)), int(r.get("wallp", 0)), false)
	for w in [[Vector3(0, 1.1, -HALF.y - 0.05), Vector3(HALF.x * 2 + 0.2, 2.2, 0.1)], [Vector3(-HALF.x - 0.05, 1.1, 0), Vector3(0.1, 2.2, HALF.y * 2 + 0.1)]]:
		var mi := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = w[1]
		mi.mesh = b; mi.position = w[0]; mi.material_override = wm; add_child(mi)
	# lišty
	Yarn.box(self, Vector3(0, 0.04, -HALF.y + 0.005), Vector3(HALF.x * 2, 0.08, 0.02), Color.WHITE)
	Yarn.box(self, Vector3(-HALF.x + 0.005, 0.04, 0), Vector3(0.02, 0.08, HALF.y * 2), Color.WHITE)
	# okno
	var wc := Vector3(win.position.x + win.size.x / 2, win.position.y + win.size.y / 2, -HALF.y)
	Yarn.box(self, wc + Vector3(0, 0, 0.01), Vector3(win.size.x + 0.1, win.size.y + 0.1, 0.03), Color.WHITE)
	Yarn.box(self, wc + Vector3(0, 0, 0.03), Vector3(win.size.x, win.size.y, 0.02), Color("a8dcff"))
	Yarn.box(self, wc + Vector3(0, 0, 0.045), Vector3(0.04, win.size.y, 0.02), Color.WHITE)
	Yarn.box(self, wc + Vector3(0, 0, 0.045), Vector3(win.size.x, 0.04, 0.02), Color.WHITE)
	Yarn.box(self, wc + Vector3(0, -win.size.y / 2 - 0.06, 0.07), Vector3(win.size.x + 0.2, 0.04, 0.12), Color.WHITE)
	for s in [-1, 1]:
		Yarn.box(self, wc + Vector3(s * (win.size.x / 2 + 0.06), 0.05, 0.08), Vector3(0.2, win.size.y + 0.25, 0.04), Data.pick(Data.YARN, r.get("curt", 0)))
	Yarn.box(self, wc + Vector3(0, win.size.y / 2 + 0.16, 0.09), Vector3(win.size.x + 0.5, 0.03, 0.03), Color("b5784a"))
	var items: Array = r.get("items", [])
	for i in items.size():
		var n := Node3D.new()
		add_child(n)
		_items.append(n)
		place(i, items[i])
		add_item(n, str(items[i][0]))
		for a in n.find_children("*", "Node3D", true, false):
			if a.has_meta("anim"): _anims.append([a, a.get_meta("anim"), a.position, a.scale])
		if i == sel:
			var e := Catalog.get_item(str(items[i][0]))
			var ring := Yarn.cyl(n, Vector3(0, 0.012, 0), 0.5, 0.5, 0.01, Data.PINK, false)
			ring.scale = Vector3(max(e["w"], 0.4) + 0.15, 1, max(e["d"], 0.4) + 0.15)
			ring.position.y = 0.012 - n.position.y

static func add_item(n: Node3D, id: String) -> void:
	var e := Catalog.get_item(id)
	if e["file"] == "":
		if not Props.build(n, id): furniture(n, id)
	else:
		var path := "res://models/%s.gltf" % e["file"]
		if not _scenes.has(path): _scenes[path] = load(path)
		var m: Node3D = _scenes[path].instantiate()
		m.scale = Vector3.ONE * float(e["scale"])
		if e.has("raise"): m.position.y = float(e["raise"]) * float(e["scale"])
		n.add_child(m)
	if e.has("light"):
		var light := OmniLight3D.new(); light.name = "light"; light.position = Vector3(0, float(e["light"]), 0)
		light.light_color = Color("ffd98a"); light.light_energy = 1.8; light.omni_range = 2.2; light.visible = false
		n.add_child(light)

## Umístí věc; věci na zeď (lift) se samy přilepí k nejbližší stěně.
func place(i: int, it: Array) -> void:
	if i >= _items.size(): return
	var e := Catalog.get_item(str(it[0]))
	var x := float(it[1]); var z := float(it[2]); var rot := float(it[3]) if it.size() > 3 else 0.0
	var y := 0.0
	if e.has("lift"):
		y = float(e["lift"])
		if abs(z + HALF.y) < abs(x + HALF.x):
			z = -HALF.y + float(e["d"]) / 2.0; rot = 0.0
		else:
			x = -HALF.x + float(e["d"]) / 2.0; rot = 90.0
		it[1] = x; it[2] = z
		if it.size() > 3: it[3] = rot
	_items[i].position = Vector3(x, y, z)
	_items[i].rotation.y = deg_to_rad(rot)

func _process(d: float) -> void:
	_t += d
	for a in _anims:
		var node: Node3D = a[0]; var m: Dictionary = a[1]; var base: Vector3 = a[2]
		if not is_instance_valid(node): continue
		var ph: float = m.get("ph", 0.0)
		match str(m["k"]):
			"fish":
				var ang := _t * float(m["sp"]) + ph
				var c: Vector3 = m["c"]
				node.position = c + Vector3(cos(ang) * float(m["rx"]), sin(_t * 1.3 + ph) * 0.02, sin(ang) * float(m["rz"]))
				node.rotation.y = -ang + (0.0 if float(m["sp"]) > 0 else PI)
			"bubble":
				var h: float = m.get("h", 0.22)
				var u := fposmod(_t * 0.5 + ph, 1.0)
				node.position = Vector3(float(m["x"]) + sin(u * 12.0) * 0.01, float(m.get("base", 0.46)) + u * h, base.z)
				node.visible = u < 0.95
			"ant":
				var u := fposmod(_t * 0.06 + ph, 1.0) * 4.0
				var corners := [Vector2(-0.24, -0.12), Vector2(0.24, -0.12), Vector2(0.24, 0.12), Vector2(-0.24, 0.12)]
				var k := int(u) % 4
				var a2: Vector2 = corners[k]; var b2: Vector2 = corners[(k + 1) % 4]
				var p := a2.lerp(b2, u - floor(u))
				node.position = Vector3(p.x, float(m["y"]) + 0.005 * sin(_t * 30.0 + ph * 9.0), p.y)
				node.rotation.y = atan2(b2.x - a2.x, b2.y - a2.y)
			"turtle":
				node.position.x = sin(_t * 0.25) * 0.18
				node.rotation.y = PI / 2 if cos(_t * 0.25) > 0 else -PI / 2
			"spin":
				node.rotation.y = _t * 1.5
				node.position.y = float(m["y"]) + sin(_t * 2.0) * 0.03
			"orbit":
				node.position = Vector3(cos(_t + ph) * 0.17, float(m["y"]) + sin(_t * 2.0 + ph) * 0.05, sin(_t + ph) * 0.17)
				node.rotation.y = _t * 3.0
			"twinkle":
				node.scale = Vector3.ONE * (0.8 + 0.25 * sin(_t * 3.0 + ph))
				node.rotation.y = _t + ph
			"sway":
				node.rotation.z = sin(_t * 1.2 + ph) * 0.06
				node.rotation.x = cos(_t + ph) * 0.04
			"wander":
				# pobíhá po pokoji kolem svého místa, občas se zastaví
				var home: Vector3 = node.get_parent().position
				if not m.has("to") or node.position.distance_to(m["to"]) < 0.04:
					if m.get("pause", false) and randf() < 0.5:
						m["wait"] = _t + randf_range(0.8, 2.5)
					var tgt := Vector3(randf_range(-1.4, 1.4), 0, randf_range(-1.0, 1.0))
					var gl := home + tgt
					gl.x = clampf(gl.x, -HALF.x + 0.25, HALF.x - 0.25); gl.z = clampf(gl.z, -HALF.y + 0.25, HALF.y - 0.25)
					m["to"] = gl - home
				if _t < float(m.get("wait", 0.0)): continue
				var dv: Vector3 = (m["to"] as Vector3) - node.position
				var step := float(m["sp"]) * get_process_delta_time()
				node.position += dv.normalized() * min(step, dv.length())
				node.rotation.y = lerp_angle(node.rotation.y, atan2(dv.x, dv.z), 0.15)
				node.position.y = abs(sin(_t * 18.0)) * 0.006
			"fly":
				var fa := _t * 0.7 + ph
				node.position = Vector3(sin(fa) * 0.8, 0.75 + sin(fa * 2.3) * 0.25, sin(fa * 2.0) * 0.45)
				node.rotation.y = atan2(cos(fa) * 0.8, cos(fa * 2.0) * 0.9)
			"flap":
				node.rotation.z = sin(_t * 22.0) * 0.9 * float(m["s"])
			"flame":
				var s0: Vector3 = a[3]
				node.scale = Vector3(s0.x, s0.y * (1 + 0.25 * sin(_t * 15.0 + base.x * 50.0)), s0.z)

## Dárek se otevře a vyskočí hvězdička s konfetami.
func open_gift(i: int) -> void:
	if i >= _items.size(): return
	var lid = _items[i].find_child("lid", true, false)
	if lid == null: return
	var tw := create_tween()
	tw.tween_property(lid, "position:y", lid.position.y + 0.25, 0.3).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(lid, "rotation:z", 0.6, 0.3)
	var s = lid.get_node_or_null("surprise")
	if s: s.visible = true
	burst(_items[i].position + Vector3(0, 0.3, 0))
	tw.tween_interval(2.0)
	tw.tween_property(lid, "position:y", lid.position.y, 0.4)
	tw.parallel().tween_property(lid, "rotation:z", 0.0, 0.4)
	tw.tween_callback(func(): if s: s.visible = false)

func burst(at: Vector3, cols := [Color("ff5d73"), Color("ffc93c"), Color("6fa8ff"), Color("5cc6b8"), Color("ff8ab3")]) -> void:
	for c in cols:
		var p := CPUParticles3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(0.03, 0.005, 0.02); p.mesh = bm
		var m := StandardMaterial3D.new(); m.albedo_color = c; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; p.material_override = m
		p.one_shot = true; p.amount = 16; p.lifetime = 1.6; p.explosiveness = 0.95
		p.direction = Vector3.UP; p.spread = 60; p.initial_velocity_min = 1.2; p.initial_velocity_max = 2.2
		p.gravity = Vector3(0, -2.5, 0); p.angular_velocity_min = -400; p.angular_velocity_max = 400
		p.position = at; add_child(p); p.emitting = true
		get_tree().create_timer(2.0).timeout.connect(p.queue_free)

## Krmení rybiček: do vody padají vločky.
func feed(i: int) -> void:
	if i >= _items.size(): return
	var top: Vector3 = _items[i].position + Vector3(0, 0.75, 0)
	burst(top, [Color("ffb020"), Color("d9734a")])

## Kousnutí: jídlo se zmenší a za chvilku zase vyroste.
func bite(i: int) -> void:
	if i >= _items.size(): return
	var n: Node3D = _items[i]
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * 0.6, 0.4)
	tw.tween_interval(2.5)
	tw.tween_property(n, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK)

## Panenka narazila do malé věci: míček se odkutálí, kostičky se rozsypou,
## vysoké drobnosti se převrhnou, ostatní se odšoupnou.
func push(i: int, dir: Vector3, items: Array) -> void:
	if i >= _items.size(): return
	var n: Node3D = _items[i]
	var id := str(items[i][0])
	dir.y = 0; dir = dir.normalized()
	var tw := create_tween()
	match id:
		"mic":
			var to := _clamp(n.position + dir * 1.1)
			tw.tween_property(n, "position", to, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			var axis := dir.cross(Vector3.UP).normalized()
			tw.parallel().tween_method(func(a): n.basis = Basis(axis, -a), 0.0, 1.1 / 0.09, 1.2).set_ease(Tween.EASE_OUT)
			items[i][1] = to.x; items[i][2] = to.z
		"kostky":
			var rng := RandomNumberGenerator.new(); rng.seed = i * 31 + int(Time.get_ticks_msec() / 1000)
			for c in n.get_children():
				if not c is MeshInstance3D: continue
				if not c.has_meta("home"): c.set_meta("home", [c.position, c.rotation])
				var off := dir * rng.randf_range(0.1, 0.35) + Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
				var t2 := create_tween()
				t2.tween_property(c, "position", Vector3(c.position.x + off.x, 0.05, c.position.z + off.z), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
				t2.parallel().tween_property(c, "rotation", Vector3(0, rng.randf_range(-1.5, 1.5), 0), 0.5)
		"voda", "kartacek", "lizatko", "zmrzlina", "hvezdnalampa", "sklenice", "budik", "hrnec":
			var to := _clamp(n.position + dir * 0.15)
			var yaw := atan2(dir.x, dir.z)
			tw.tween_property(n, "position", to, 0.35)
			tw.parallel().tween_property(n, "rotation", Vector3(PI / 2, yaw, 0), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			items[i][1] = to.x; items[i][2] = to.z
			# po chvilce se věc zase postaví, ať se dá dál používat
			tw.tween_interval(3.0)
			tw.tween_property(n, "rotation", Vector3(0, deg_to_rad(float(items[i][3])), 0), 0.4).set_trans(Tween.TRANS_BACK)
		_:
			var to := _clamp(n.position + dir * 0.28)
			tw.tween_property(n, "position", to + Vector3(0, 0.06, 0), 0.15)
			tw.tween_property(n, "position", to, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(n, "rotation:y", n.rotation.y + randf_range(-0.8, 0.8), 0.35)
			items[i][1] = to.x; items[i][2] = to.z

## Hraní s kostkami: zase se postaví do komínku.
func restack(i: int) -> void:
	if i >= _items.size(): return
	for c in _items[i].get_children():
		if c.has_meta("home"):
			var h: Array = c.get_meta("home")
			var t2 := create_tween()
			t2.tween_property(c, "position", h[0], 0.6).set_trans(Tween.TRANS_BACK)
			t2.parallel().tween_property(c, "rotation", h[1], 0.6)

func _clamp(v: Vector3) -> Vector3:
	return Vector3(clampf(v.x, -HALF.x + 0.15, HALF.x - 0.15), v.y, clampf(v.z, -HALF.y + 0.15, HALF.y - 0.15))

func node_pos(i: int) -> Vector3:
	return _items[i].position if i < _items.size() else Vector3(99, 0, 99)

## Kde je teď živé zvířátko (pobíhá mimo své místo).
func live_pos(i: int) -> Vector3:
	if i >= _items.size(): return Vector3(99, 0, 99)
	for a in _anims:
		if a[1]["k"] in ["wander", "fly"] and is_instance_valid(a[0]) and a[0].get_parent() == _items[i]:
			var g: Vector3 = a[0].global_position
			return Vector3(g.x, 0, g.z)
	return _items[i].position

## Srdíčka, která stoupají nad panenkou při mazlení.
func hearts(at: Vector3) -> void:
	for k in 3:
		var h := Node3D.new(); add_child(h)
		h.position = at + Vector3(randf_range(-0.12, 0.12), 0, randf_range(-0.05, 0.05))
		var col: Color = [Color("ff5d8f"), Color("ff8ab3"), Color("ff3b6b")][k]
		var mat := Props.glow(col)
		for s in [-1, 1]:
			var b := Yarn.ball(h, Vector3(0.022 * s, 0.0, 0), Vector3(0.05, 0.05, 0.03), col, false); b.material_override = mat
		var tip := Yarn.cyl(h, Vector3(0, -0.028, 0), 0.0, 0.045, 0.05, col, false, Vector3(PI, 0, 0)); tip.material_override = mat
		tip.scale = Vector3(1, 1, 0.35)
		h.scale = Vector3.ONE * 0.01
		var tw := create_tween()
		tw.tween_interval(k * 0.25)
		tw.tween_property(h, "scale", Vector3.ONE * 1.2, 0.25).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(h, "position:y", h.position.y + 0.55, 1.6)
		tw.tween_property(h, "scale", Vector3.ONE * 0.01, 0.3)
		tw.tween_callback(h.queue_free)

func bubbles(at: Vector3) -> void:
	burst(at, [Color.WHITE, Color("e8f6ff")])

func move_item(i: int, to: Vector3) -> void:
	if i < _items.size():
		create_tween().tween_property(_items[i], "position", to, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func toggle_lamp(i: int) -> void:
	if i < _items.size():
		var l = _items[i].get_node_or_null("light")
		if l: l.visible = not l.visible

## Obrázková tapeta: obrázek 3 m široký přes celou výšku stěny, opakuje se do stran.
static func mural_mat(k: int) -> StandardMaterial3D:
	var key := "mural%d" % k
	if _pattern_cache.has(key): return _pattern_cache[key]
	var m := StandardMaterial3D.new(); m.roughness = 0.9
	m.albedo_texture = mural_tex(k)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(1.0 / 3.0, -1.0 / 2.2, 1.0 / 3.0)
	m.uv1_offset = Vector3(0, 0.5, 0)
	_pattern_cache[key] = m
	return m

static func mural_tex(k: int) -> Texture2D:
	return load("res://wallpapers/%s.png" % Data.MURALS[clampi(k, 0, Data.MURALS.size() - 1)])

## Materiál se vzorem (tapety a podlahy), vzor se kreslí v kódu.
static func pattern_mat(c: Color, kind: int, is_floor: bool) -> StandardMaterial3D:
	var key := "%s-%d-%s" % [c.to_html(), kind, is_floor]
	if _pattern_cache.has(key): return _pattern_cache[key]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var light := c.lightened(0.35); var dark := c.darkened(0.12)
	for y in n:
		for x in n:
			var col := c
			if is_floor:
				match kind:
					1: col = dark if y % 16 == 0 or (x == (y / 16) * 21 % 64) else c.darkened(0.03 * ((y / 16) % 2))
					2: col = Color.WHITE.lerp(c, 0.4) if x % 32 == 0 or y % 32 == 0 else c
					3: col = c.lightened(0.45) if ((x / 32) + (y / 32)) % 2 == 0 else c
			else:
				match kind:
					1: col = light if (x / 8) % 2 == 0 else c
					2: col = light if Vector2(x % 32, y % 32).distance_to(Vector2(16, 16)) < 5 or Vector2((x + 16) % 32, (y + 16) % 32).distance_to(Vector2(16, 16)) < 5 else c
					3:
						var px := x % 32 - 16; var py := y % 32 - 16
						col = Color.WHITE if (abs(px) + abs(py) * 2 < 7 or abs(px) * 2 + abs(py) < 7) else c
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(1.2, 1.2, 1.2) if is_floor else Vector3(2.5, 2.5, 2.5)
	m.roughness = 0.9
	_pattern_cache[key] = m
	return m

## Hračky a herní stůl poskládané v kódu.
static func furniture(n: Node3D, id: String) -> void:
	var wood := Color("b5784a")
	match id:
		"hernistul":
			var t := Node3D.new(); n.add_child(t)
			add_item(t, "stul1")
			for z in [0.45, -0.45]:
				var s := Node3D.new(); s.position.z = z; n.add_child(s)
				add_item(s, "stolicka1")
			# barevný ubrus, ať je poznat, že se tu hraje
			Yarn.box(n, Vector3(0, 0.505, 0), Vector3(0.42, 0.01, 0.42), Data.PINK)
		"kytka":
			Yarn.cyl(n, Vector3(0, 0.09, 0), 0.12, 0.09, 0.18, Color("d9734a"))
			for l in [Vector3(0, 0.33, 0), Vector3(0.09, 0.27, 0.03), Vector3(-0.08, 0.28, -0.03), Vector3(0.02, 0.25, 0.09)]:
				Yarn.ball(n, l, Vector3(0.14, 0.22, 0.14), Color("5cbf6e"))
			for f in [Vector3(0.06, 0.4, 0.05), Vector3(-0.07, 0.38, 0.02)]:
				Yarn.ball(n, f, Vector3(0.07, 0.07, 0.07), Color("ff7ab8"))
		"medvidek":
			var br := Color("b98058")
			Yarn.ball(n, Vector3(0, 0.1, 0), Vector3(0.2, 0.2, 0.18), br)
			Yarn.ball(n, Vector3(0, 0.26, 0), Vector3(0.17, 0.16, 0.16), br)
			for s in [-1, 1]:
				Yarn.ball(n, Vector3(0.065 * s, 0.33, 0), Vector3(0.06, 0.06, 0.04), br)
				Yarn.ball(n, Vector3(0.035 * s, 0.28, 0.07), Vector3(0.02, 0.02, 0.02), Color("2a2230"), false)
				Yarn.ball(n, Vector3(0.09 * s, 0.13, 0.02), Vector3(0.07, 0.11, 0.07), br)
			Yarn.ball(n, Vector3(0, 0.245, 0.075), Vector3(0.06, 0.045, 0.04), Color("ead0b0"))
		"mic":
			Yarn.ball(n, Vector3(0, 0.09, 0), Vector3(0.18, 0.18, 0.18), Color("ff7a59"))
			Yarn.cyl(n, Vector3(0, 0.09, 0), 0.092, 0.092, 0.03, Color("ffc93c"))
		"kostky":
			var cols := [Color("ff5d73"), Color("3a8dde"), Color("ffc93c"), Color("4fbf6e"), Color("9b7cff")]
			var spots := [Vector3(-0.08, 0.05, 0), Vector3(0.05, 0.05, 0.06), Vector3(0.07, 0.05, -0.07), Vector3(-0.02, 0.15, 0.0), Vector3(0.1, 0.15, -0.02)]
			for k in spots.size():
				Yarn.box(n, spots[k], Vector3(0.1, 0.1, 0.1), cols[k])
		"autick":
			Yarn.box(n, Vector3(0, 0.07, 0), Vector3(0.14, 0.07, 0.26), Color("3a8dde"))
			Yarn.box(n, Vector3(0, 0.13, -0.02), Vector3(0.12, 0.06, 0.13), Color("bfe6ff"))
			for x in [-0.075, 0.075]:
				for z in [-0.08, 0.08]:
					Yarn.cyl(n, Vector3(x, 0.035, z), 0.035, 0.035, 0.03, Color("2a2230"), false, Vector3(0, 0, PI / 2))
