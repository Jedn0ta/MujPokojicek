extends Control
## Hlavní obrazovka (na šířku): vlevo záložky, uprostřed 3D pokojíček, vpravo nabídka.
## Ovládání pro malé děti: obrázková tlačítka, skoro žádný text.
## Kamera: tažení jedním prstem otáčí, dvěma prsty přibližuje a posouvá, tlačítka + − ⟳.
## Ťuknutí na věc = panenka k ní dojde a něco s ní udělá. Ťuknutí na okno = minihra.

const Net := preload("res://net.gd")
const Doll := preload("res://doll.gd")
const Room := preload("res://room.gd")
const Pexeso := preload("res://pexeso.gd")
const Card := preload("res://card.gd")
const Outside := preload("res://outside.gd")
const Frame := preload("res://window_frame.gd")
const WIcon := preload("res://weather_icon.gd")
const UIcon := preload("res://ui_icon.gd")
const OUT := Vector3(200, 0, 0)
const Updater := preload("res://updater.gd")
const PixelEditor := preload("res://pixel_editor.gd")
const PANEL_W := 350.0

var S: Dictionary
var tab := "hero"
var tray: VBoxContainer
var net: Node
var pex: Node
var tabs := {}
var status_label: Label
var found_box: VBoxContainer
var found_ips := {}

var people := {}
var doll_nodes := {}
var visiting_room := {}
var edit_mode := false
var paths := Paths.new()
var push_cool := {}
var window_view := false
var cat := "postele"
var outside: Node3D
var frame: Control
var env: Environment
var sun: DirectionalLight3D

var stage: Control
var vpc: SubViewportContainer
var cam: Camera3D
var room: Node3D
var dolls: Node3D
var pedestal: Node3D
var sel := -1
var dragging := -1
var spin := 0.35
var mode_btn: Control
var cam_btns: Control

# kamera
var cam_target := Vector3(0, 0.3, -0.1)
var cam_yaw := 0.15
var cam_pitch := 0.62
var cam_dist := 6.6
var _cur := {"t": Vector3.ZERO, "yaw": 0.0, "pitch": 0.6, "dist": 6.0}
var touches := {}     # prst -> poloha
var _down_pos := Vector2.ZERO
var _down_time := 0
var _moved := false
var _pinch := 0.0

# minihra za oknem
var wg := {"phase": "idle", "pane": -1, "tries": 0}
# modelína
var sculpt_tool := ""      # "", "pull", "push", "smooth"
var sculpt_size := 0.45
var sculpt_mirror := true
var sculpting := false
var head_region := "brada"   # čumáček, oči a pusa se vybírají zvlášť z hotových kousků

var updater: Node
var upd_btn: Control
var upd_label: Label
var gear_btn: Control
var settings_open := false
var tray_scroll: ScrollContainer
var overlay: PanelContainer
var game_info: Label
var cards: Array = []

func _ready() -> void:
	S = Data.load_state()
	Data.apply_theme(str(S.get("theme", "girl")))
	theme = _make_theme()
	var bg := ColorRect.new(); bg.color = Data.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var m := MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + side, 14)
	add_child(m)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 14); m.add_child(row)
	var left := VBoxContainer.new(); left.add_theme_constant_override("separation", 16); row.add_child(left)
	for t in ["hero", "room", "friends"]:
		var b := UIcon.new({"hero": "doll_boy" if Data.theme == "boy" else "doll", "room": "house", "friends": "friends"}[t], null, Color(0, 0, 0, 0), 96)
		b.round_btn = true
		b.tapped.connect(_set_tab.bind(t)); left.add_child(b); tabs[t] = b
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; left.add_child(spacer)
	Snd.music_on = bool(S.get("music", true))
	var snd := Snd.new(); add_child(snd)
	Snd.sfx_on = bool(S.get("sfx", true)); Snd.set_volumes(float(S.get("mvol", 0.7)), float(S.get("svol", 0.9)))
	gear_btn = UIcon.new("settings", null, Color(0, 0, 0, 0), 80); gear_btn.round_btn = true
	gear_btn.tapped.connect(func():
		settings_open = not settings_open; gear_btn.selected = settings_open; gear_btn.queue_redraw()
		if settings_open and window_view: _leave_window(false); _refresh_stage()
		_build_tray())
	left.add_child(gear_btn)
	stage = Control.new(); stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL; stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	row.add_child(stage)
	vpc = SubViewportContainer.new(); vpc.stretch = true; vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	vpc.gui_input.connect(_on_stage_input)
	stage.add_child(vpc)
	var vp := SubViewport.new(); vp.own_world_3d = true; vp.msaa_3d = Viewport.MSAA_4X
	vpc.add_child(vp)
	_build_world(vp)
	frame = Frame.new(); frame.visible = false; frame.set_anchors_preset(Control.PRESET_FULL_RECT); stage.add_child(frame)
	# tlačítka kamery v rohu scény
	cam_btns = HBoxContainer.new(); cam_btns.add_theme_constant_override("separation", 10)
	cam_btns.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); cam_btns.position = Vector2(14, -94); cam_btns.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stage.add_child(cam_btns)
	for k in ["plus", "minus", "reset"]:
		var b := UIcon.new(k, null, Color(0, 0, 0, 0), 76); b.round_btn = true
		b.tapped.connect(_cam_button.bind(k)); cam_btns.add_child(b)
	mode_btn = UIcon.new("edit", null, Color(0, 0, 0, 0), 90); mode_btn.round_btn = true
	mode_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT); mode_btn.position = Vector2(-104, 14)
	mode_btn.tapped.connect(func(): edit_mode = not edit_mode; sel = -1; _refresh_stage(); _build_tray())
	stage.add_child(mode_btn)
	var panel := PanelContainer.new(); panel.custom_minimum_size.x = PANEL_W
	panel.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.75), Data.LILAC, 4))
	row.add_child(panel)
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	# posouvání prstem: tažení kdekoli v menu (i přes tlačítka) posune menu
	sc.gui_input.connect(func(e):
		if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
			sc.scroll_vertical -= int(e.relative.y)
		elif e is InputEventScreenDrag:
			sc.scroll_vertical -= int(e.relative.y))
	tray_scroll = sc
	tray = VBoxContainer.new(); tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray.add_theme_constant_override("separation", 12); sc.add_child(tray)
	_build_overlay()

	net = Net.new(); net.name = "Net"; add_child(net)
	net.status.connect(func(t): if status_label: status_label.text = t)
	net.found.connect(_on_found)
	net.joined.connect(_on_joined)
	net.left.connect(_on_left)
	net.welcome.connect(func(r, rm): visiting_room = rm; people = r; _refresh_stage(); _build_tray())
	net.roster.connect(func(r): people = r; _refresh_stage())
	net.cmd.connect(func(id, c): if id != net.my_id(): _do_cmd(id, c))
	net.flip.connect(func(id, i): pex.flip(id, i))
	net.game.connect(_on_game)
	net.lost.connect(_go_home)
	updater = Updater.new(); add_child(updater)
	updater.status.connect(_on_update_status)
	pex = Pexeso.new(); add_child(pex)
	pex.changed.connect(func(st): net.send_game(st); _on_game(st))
	_people_reset()
	_set_tab("hero")
	if not S.has("theme"): _theme_picker.call_deferred()

func _build_world(vp: SubViewport) -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Data.STAGE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff4fb"); env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-60, 25, 0)
	sun.light_energy = 0.25; sun.shadow_enabled = false; vp.add_child(sun)
	cam = Camera3D.new(); vp.add_child(cam)
	room = Room.new(); vp.add_child(room)
	pedestal = Node3D.new(); vp.add_child(pedestal)
	Yarn.cyl(pedestal, Vector3(0, -0.03, 0), 0.45, 0.5, 0.06, Color("cdbcff"))
	dolls = Node3D.new(); vp.add_child(dolls)
	outside = Outside.new(); outside.position = OUT; outside.env = env; outside.sun = sun
	vp.add_child(outside); outside.build()
	outside.set_view(int(S.get("view", 0)))
	outside.set_weather(int(S.get("weather", 0)), false)

var _heart_t := 0.0
func _process(d: float) -> void:
	if _pix_dirty > 0 and Time.get_ticks_msec() > _pix_dirty:
		_pix_dirty = 0; Data.save_state(S); room.build(current_room(), sel if edit_mode else -1)
	_bump_small_things()
	if hold_cand >= 0 and touches.size() == 1 and not _moved and Time.get_ticks_msec() - _down_time > 450:
		hold_item = hold_cand; hold_cand = -1; _moved = true; dragging = -1
		Snd.play("pop"); _lift_held()
	_heart_t += d
	if _heart_t > 0.9 and tab != "hero" and not window_view:
		_heart_t = 0.0
		var items: Array = current_room()["items"]
		for id in doll_nodes:
			var dn = doll_nodes[id]
			var c: Dictionary = people[id]["cmd"] if people.has(id) else {}
			var i := int(c.get("item", -1))
			if not dn.walking and c.get("act") in ["hug", "pet"] and i >= 0 and i < items.size() and Catalog.get_item(str(items[i][0])).get("cuddly", false):
				room.hearts(dn.position + Vector3(0, 1.1 * dn.scale.y, 0))
	_update_progress()
	_update_camera(d)

# ---------- aktualizace z GitHubu ----------

var _upd_state := ""
var _apk_url := ""

func _on_update_tap() -> void:
	match _upd_state:
		"done": updater.restart()
		"apk": if _apk_url != "": OS.shell_open(_apk_url)
		"checking", "downloading": pass
		_: updater.check()

func _on_update_status(kind: String, text: String) -> void:
	_upd_state = kind
	_upd_text()
	if not is_instance_valid(upd_btn): return
	upd_btn.progress = -1.0
	upd_btn.selected = false
	match kind:
		"checking", "downloading": upd_btn.kind = "update"; upd_btn.progress = 0.02
		"done": upd_btn.kind = "check"; upd_btn.selected = true   # další ťuknutí = spustit novou verzi
		"latest": upd_btn.kind = "check"
		"apk": _apk_url = text; upd_btn.kind = "update"; upd_btn.selected = true
		"error": upd_btn.kind = "update"
	upd_btn.queue_redraw()

func _update_progress() -> void:
	if _upd_state == "downloading" and is_instance_valid(upd_btn):
		upd_btn.progress = max(0.02, updater.progress()); upd_btn.queue_redraw()

# ---------- kamera ----------

func _cam_defaults() -> void:
	if tab == "hero":
		cam_target = Vector3(0, 0.55, 0); cam_yaw = 0.0; cam_pitch = 0.08; cam_dist = 3.0
		if hero_tab in ["oci", "pusa", "vlasy", "hlava"]: cam_target.y = 0.74; cam_dist = 2.1
	else:
		cam_target = Vector3(0, 0.3, -0.1); cam_yaw = 0.12; cam_pitch = 0.6; cam_dist = 7.8

func _clamp_camera() -> void:
	if tab == "hero":
		cam_dist = clampf(cam_dist, 1.1, 4.2)
		cam_target.y = lerpf(0.55, 0.78, clampf((3.0 - cam_dist) / 1.9, 0, 1))
	else:
		cam_dist = clampf(cam_dist, 2.2, 10.5)
		cam_pitch = clampf(cam_pitch, 0.22, 1.25)
		cam_yaw = clampf(cam_yaw, -0.35, 1.3)
		cam_target.x = clampf(cam_target.x, -2.8, 2.8); cam_target.z = clampf(cam_target.z, -1.6, 1.6)

func _cam_button(k: String) -> void:
	match k:
		"plus": cam_dist *= 0.8
		"minus": cam_dist *= 1.25
		"reset": _cam_defaults()
	_clamp_camera()

func _update_camera(d: float) -> void:
	if window_view:
		cam.position = OUT + Vector3(0, 1.3, 4.6); cam.fov = 50
		cam.look_at(OUT + outside.look)
		return
	var k := clampf(d * 8.0, 0.0, 1.0)
	_cur["t"] = (_cur["t"] as Vector3).lerp(cam_target, k)
	_cur["yaw"] = lerpf(_cur["yaw"], cam_yaw, k)
	_cur["pitch"] = lerpf(_cur["pitch"], cam_pitch, k)
	_cur["dist"] = lerpf(_cur["dist"], cam_dist, k)
	var dir := Vector3(sin(_cur["yaw"]) * cos(_cur["pitch"]), sin(_cur["pitch"]), cos(_cur["yaw"]) * cos(_cur["pitch"]))
	cam.fov = 32 if tab == "hero" else 42
	cam.position = _cur["t"] + dir * _cur["dist"]
	cam.look_at(_cur["t"])

func _snap_camera() -> void:
	_cur = {"t": cam_target, "yaw": cam_yaw, "pitch": cam_pitch, "dist": cam_dist}

# ---------- lidé v pokoji ----------

func _people_reset() -> void:
	people = {net.my_id(): {"data": S, "cmd": {}}}

func _roster() -> Dictionary:
	return people.duplicate()

func current_room() -> Dictionary:
	return visiting_room if net.is_client and not visiting_room.is_empty() else S["room"]

func _on_joined(id: int, d: Dictionary) -> void:
	people[id] = {"data": d, "cmd": {}}
	_refresh_stage()
	net.send_welcome(id, _roster(), S["room"])
	net.send_roster(_roster())

func _on_left(id: int) -> void:
	people.erase(id)
	_check_tables()
	net.send_roster(_roster())
	_refresh_stage()

func _go_home() -> void:
	net.stop()
	pex.stop()
	visiting_room = {}
	overlay.visible = false
	_people_reset()
	_refresh_stage()

func _do_cmd(id: int, c: Dictionary) -> void:
	if not people.has(id): return
	people[id]["cmd"] = c
	if doll_nodes.has(id):
		var d = doll_nodes[id]
		var goal := Vector3(float(c.get("ax", d.position.x)), 0, float(c.get("az", d.position.z)))
		d.command(c, false, paths.route(d.position, goal))
	_check_tables()

func _my_cmd(c: Dictionary) -> void:
	_do_cmd(net.my_id(), c)
	net.send_cmd(c)

## Panenka došla na místo: míč odletí, lampa se rozsvítí, u stolu se může začít hrát.
func _on_arrived(c: Dictionary, _id: int) -> void:
	var items: Array = current_room()["items"]
	var i := int(c.get("item", -1))
	var iid: String = str(items[i][0]) if i >= 0 and i < items.size() else ""
	Snd.play(Snd.for_item(iid, str(c.get("act", ""))))
	match str(c.get("act", "")):
		"kick":
			if i >= 0 and i < items.size():
				items[i][1] = c["bx"]; items[i][2] = c["bz"]
				room.move_item(i, Vector3(float(c["bx"]), 0, float(c["bz"])))
		"lamp":
			room.toggle_lamp(i)
		"open":
			if iid == "kufr" and _id == net.my_id() and not net.is_client:
				chest_open = i; _build_tray()
			else:
				room.open_gift(i)
		"feed":
			room.feed(i)
		"eat":
			room.bite(i)
		"play":
			room.restack(i)
		"bath", "wash", "brush":
			if doll_nodes.has(_id): room.bubbles(doll_nodes[_id].position + Vector3(0, 0.6, 0))
		"window":
			if _id == net.my_id() and tab != "hero":
				_enter_window.call_deferred()
	if _id == net.my_id() and i >= 0 and i < items.size():
		_toast(Catalog.tip(Catalog.get_item(str(items[i][0]))))
	_check_tables()

## Když jde panenka kolem malé věci, odstrčí ji (každý to vidí stejně u sebe).
func _bump_small_things() -> void:
	if tab == "hero" or window_view or room == null or not room.visible: return
	var items: Array = current_room()["items"]
	var now := Time.get_ticks_msec()
	for id in doll_nodes:
		var d = doll_nodes[id]
		if not d.walking: continue
		var aim := int(d.cmd.get("item", -1))
		var fwd := Vector3(sin(d.rotation.y), 0, cos(d.rotation.y))
		for i in items.size():
			if i == aim or push_cool.get(i, 0) > now: continue
			var e := Catalog.get_item(str(items[i][0]))
			if not Paths.is_small(e) or e.get("live", false): continue
			var p: Vector3 = room.node_pos(i)
			if Vector2(p.x - d.position.x, p.z - d.position.z).length() < 0.17:
				room.push(i, fwd + (p - d.position).normalized() * 0.5, items)
				push_cool[i] = now + 1200
				if not net.is_client and current_room() == S["room"]: Data.save_state(S)

## Jen hostitel (nebo hra bez kamarádů) hlídá, kdo sedí u stolu, a spouští pexeso.
func _check_tables() -> void:
	if net.is_client: return
	var items: Array = current_room()["items"]
	var seated := {}
	for id in people:
		var c: Dictionary = people[id]["cmd"]
		var i := int(c.get("item", -1))
		if c.get("act") == "sit" and i >= 0 and i < items.size() and Catalog.get_item(str(items[i][0]))["act"] == "game" \
				and doll_nodes.has(id) and not doll_nodes[id].walking:
			if not seated.has(i): seated[i] = []
			seated[i].append(id)
	if pex.active():
		var t := int(pex.st.get("table", -1))
		for p in pex.st["players"]:
			if p != -1 and not (seated.has(t) and p in seated[t]):
				pex.stop()
				return
		return
	var names := {-1: "Počítač"}
	for id in people: names[id] = str(people[id]["data"].get("name", "?"))
	for t in seated:
		if seated[t].size() >= 2:
			pex.start([seated[t][0], seated[t][1]], names); pex.st["table"] = t
			return
		if people.size() == 1:
			pex.start([seated[t][0], -1], names); pex.st["table"] = t
			return


## Bublina s tipem pro rodiče nahoře nad scénou.
var _toast_label: Label
func _toast(t: String) -> void:
	if t == "" or tab == "hero": return
	if _toast_label == null:
		_toast_label = Label.new(); _toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.add_theme_stylebox_override("normal", _box(Color(1, 1, 1, 0.94), Data.PINK, 5))
		_toast_label.add_theme_font_size_override("font_size", 24)
		_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(_toast_label)
	_toast_label.text = t
	_toast_label.position = Vector2(120, 14)
	_toast_label.size = Vector2(stage.size.x - 240, 0)
	_toast_label.visible = true
	_toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(_toast_label, "modulate:a", 0.0, 0.6)

# ---------- scéna ----------

func _set_tab(t: String) -> void:
	tab = t
	settings_open = false
	if gear_btn: gear_btn.selected = false; gear_btn.queue_redraw()
	_cam_defaults(); _snap_camera()
	for k in tabs:
		tabs[k].selected = k == t; tabs[k].queue_redraw()
	sel = -1
	if window_view: _leave_window(false)
	_refresh_stage(); _build_tray()

func _refresh_stage() -> void:
	for c in dolls.get_children(): c.free()
	doll_nodes.clear()
	mode_btn.visible = tab == "room" and not net.is_client and not window_view
	mode_btn.kind = "play" if edit_mode else "edit"; mode_btn.queue_redraw()
	cam_btns.visible = not window_view
	if tab == "hero":
		room.visible = false; pedestal.visible = true; frame.visible = false; outside.restore_room()
		# portrétní světlo: slabší slunce, víc měkkého světla, ať obličej není přepálený
		sun.light_energy = 0.22; env.ambient_light_energy = 0.5
		var d := _new_doll(S["hero"]); dolls.add_child(d); d.build(S["hero"]); d.rotation.y = spin
		return
	room.visible = true; pedestal.visible = false
	room.build(current_room(), sel if tab == "room" and edit_mode else -1)
	paths.build(current_room()["items"])
	var ids := people.keys()
	for k in ids.size():
		var id: int = ids[k]
		var hd: Dictionary = people[id]["data"].get("hero", {})
		var d := _new_doll(hd); dolls.add_child(d); d.build(hd)
		d.arrived.connect(_on_arrived.bind(id))
		doll_nodes[id] = d
		var c: Dictionary = people[id]["cmd"]
		if c.is_empty():
			c = Interact.walk((k - (ids.size() - 1) / 2.0) * 0.5, 0.6); c["ry"] = 0.0
			people[id]["cmd"] = c
		d.command(c, true)
	frame.visible = window_view
	if window_view: outside.apply_sky()
	else: outside.restore_room()

func _floor_hit(p: Vector2):
	return Plane(Vector3.UP, 0).intersects_ray(cam.project_ray_origin(p), cam.project_ray_normal(p))

func _nearest_item(items: Array, hit: Vector3) -> int:
	var found := -1
	var best := 1.0
	for i in items.size():
		var e := Catalog.get_item(str(items[i][0]))
		var reach: float = max(float(e["w"]), float(e["d"])) / 2.0 + 0.12
		var dd := Vector2(float(items[i][1]) - hit.x, float(items[i][2]) - hit.z).length() / reach
		if e["act"] == "dance": dd += 0.35
		if dd < best: best = dd; found = i
	return found

# ---------- dotyky ----------

func _on_stage_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed: _p_down(e.index, e.position)
		else: _p_up(e.index, e.position)
	elif e is InputEventScreenDrag:
		_p_move(e.index, e.position, e.relative)
	elif e is InputEventMouse and e.device == InputEvent.DEVICE_ID_EMULATION:
		return   # myš napodobená z prstu: prsty už řešíme výše
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed: cam_dist *= 0.9; _clamp_camera()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed: cam_dist *= 1.1; _clamp_camera()
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed: _p_down(0, e.position)
			else: _p_up(0, e.position)
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_p_move(0, e.position, e.relative)

var win_drag := false
var hold_cand := -1      # věc pod prstem, než se podrží
var hold_item := -1      # věc, kterou dítě právě nese
var chest_open := -1     # otevřený kouzelný kufr

## Věc se nesmí dostat do zdi: střed omezíme podle velikosti a natočení.
func _clamp_item(it: Array) -> void:
	var e := Catalog.get_item(str(it[0]))
	if e.has("lift"): return
	var a := deg_to_rad(float(it[3]) if it.size() > 3 else 0.0)
	var w := float(e["w"]) * 0.5; var d := float(e["d"]) * 0.5
	var hx := absf(cos(a)) * w + absf(sin(a)) * d; var hz := absf(sin(a)) * w + absf(cos(a)) * d
	it[1] = clampf(float(it[1]), -Room.HALF.x + hx + 0.02, Room.HALF.x - hx - 0.02)
	it[2] = clampf(float(it[2]), -Room.HALF.y + hz + 0.02, Room.HALF.y - hz - 0.02)

func _rotate_item(i: int) -> void:
	var items: Array = S["room"]["items"]
	if i < 0 or i >= items.size(): return
	var it: Array = items[i]
	while it.size() < 4: it.append(0.0)
	it[3] = fmod(float(it[3]) + 45.0, 360.0)
	_clamp_item(it); room.place(i, it); Snd.play("klap", 0.1, -4.0)
	Data.save_state(S); paths.build(items)

# --- tažení věci z nabídky do pokojíčku ---
var last_moved := -1      # naposledy přenesená věc (mimo zařizování jde otočit)
var drag_new := ""        # id věci, kterou dítě táhne z nabídky
var drag_idx := -1        # její index v pokojíčku (jakmile prst vjede nad pokoj)

func _start_drag_new(id: String) -> void:
	if net.is_client: return
	drag_new = id; drag_idx = -1
	var items: Array = S["room"]["items"]
	for j in items.size():
		if str(items[j][0]) == id: drag_idx = j   # věc už v pokoji je: jen ji přesuneme

func _input(e: InputEvent) -> void:
	if drag_new == "": return
	var gp := Vector2.ZERO; var moved := false; var released := false
	if e is InputEventScreenDrag: gp = e.position; moved = true
	elif e is InputEventScreenTouch and not e.pressed: gp = e.position; released = true
	elif e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION: gp = e.position; moved = true
	elif e is InputEventMouseButton and e.device != InputEvent.DEVICE_ID_EMULATION and not e.pressed: gp = e.position; released = true
	else: return
	get_viewport().set_input_as_handled()
	var p: Vector2 = gp - stage.global_position
	var over := Rect2(Vector2.ZERO, stage.size).has_point(p)
	var items: Array = S["room"]["items"]
	if moved and over:
		var hit = _floor_hit(p)
		if hit == null: return
		if drag_idx < 0:
			var r: Dictionary = S["room"]
			if r.get("chest", []).has(drag_new): r["chest"].erase(drag_new)
			items.append([drag_new, hit.x, hit.z, 0, 0.0]); drag_idx = items.size() - 1
			_refresh_stage(); Snd.play("pop")
		var it: Array = items[drag_idx]
		while it.size() < 5: it.append(0.0)
		it[1] = hit.x; it[2] = hit.z
		_clamp_item(it)
		it[4] = room.top_at(it[1], it[2], drag_idx) if _small(str(it[0])) else 0.0
		room.place(drag_idx, it)
		var n: Node3D = room.item_node(drag_idx)
		if n: n.position.y += 0.12
	if released:
		if drag_idx >= 0:
			sel = drag_idx if edit_mode else -1
			Data.save_state(S); _refresh_stage(); paths.build(items)
		drag_new = ""; drag_idx = -1
		_build_tray()

func _small(id: String) -> bool:
	var e := Catalog.get_item(id)
	return float(e["w"]) * float(e["d"]) < 0.2 and not e.has("lift")

func _own_room() -> bool:
	return tab == "room" and not net.is_client and not window_view
var _win_off := Vector2.ZERO

func _lift_held() -> void:
	var n: Node3D = room.item_node(hold_item)
	if n: n.position.y += 0.15

func _chest_near(it: Array, skip: int) -> int:
	var items: Array = S["room"]["items"]
	for k in items.size():
		if k != skip and str(items[k][0]) == "kufr" and Vector2(float(items[k][1]) - float(it[1]), float(items[k][2]) - float(it[2])).length() < 0.4:
			return k
	return -1

func _wall_hit(p: Vector2):
	var h = Plane(Vector3(0, 0, 1), -Room.HALF.y + 0.05).intersects_ray(cam.project_ray_origin(p), cam.project_ray_normal(p))
	return null if h == null else Vector2(h.x, h.y)

## Větší / menší okno (tlačítka v zařizování).
func _win_size(dw: float, dh: float) -> void:
	var w: Rect2 = Room.win_of(S["room"])
	var c := w.get_center()
	S["room"]["win"] = [c.x - (w.size.x + dw) / 2, c.y - (w.size.y + dh) / 2, w.size.x + dw, w.size.y + dh]
	var n: Rect2 = Room.win_of(S["room"])
	S["room"]["win"] = [n.position.x, n.position.y, n.size.x, n.size.y]
	Data.save_state(S); _refresh_stage()

func _p_down(i: int, p: Vector2) -> void:
	touches[i] = p
	if touches.size() == 1:
		_down_pos = p; _down_time = Time.get_ticks_msec(); _moved = false
		dragging = -1
		if tab == "hero" and sculpt_tool != "" and int(S["hero"].get("headshape", 0)) == HeadShape.CUSTOM and dolls.get_child_count() > 0 and dolls.get_child(0).has_method("sculpt_ray"):
			var hit = dolls.get_child(0).sculpt_ray(cam.project_ray_origin(p), cam.project_ray_normal(p))
			if hit != null:
				sculpting = true; _moved = true
				dolls.get_child(0).sculpt_brush(hit, sculpt_tool, sculpt_size, sculpt_mirror)
				return
		hold_cand = -1
		if _own_room():
			var fh = _floor_hit(p)
			if fh != null: hold_cand = _nearest_item(S["room"]["items"], fh)
		if tab == "room" and edit_mode and not net.is_client and not window_view:
			var wh = _wall_hit(p)
			if wh != null and Room.win.grow(0.05).has_point(wh):
				win_drag = true; _win_off = Room.win.position - wh; _moved = true
				return
			var hit = _floor_hit(p)
			if hit != null:
				var it := _nearest_item(S["room"]["items"], hit)
				if it >= 0 and it == sel: dragging = it
	elif touches.size() == 2:
		_moved = true; dragging = -1
		_pinch = (touches.values()[0] as Vector2).distance_to(touches.values()[1])

func _p_move(i: int, p: Vector2, rel: Vector2) -> void:
	if not touches.has(i): return
	touches[i] = p
	if sculpting and dolls.get_child(0).has_method("sculpt_ray"):
		var hit = dolls.get_child(0).sculpt_ray(cam.project_ray_origin(p), cam.project_ray_normal(p))
		if hit != null: dolls.get_child(0).sculpt_brush(hit, sculpt_tool, sculpt_size, sculpt_mirror)
		return
	if p.distance_to(_down_pos) > 14: _moved = true
	if window_view: return
	if touches.size() >= 2:
		var a: Vector2 = touches.values()[0]; var b: Vector2 = touches.values()[1]
		var dnow := a.distance_to(b)
		if _pinch > 10: cam_dist *= _pinch / max(dnow, 10)
		_pinch = dnow
		if tab != "hero":
			var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw)); var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
			cam_target += (-right * rel.x + fwd * rel.y) * 0.004 * cam_dist * 0.5
		_clamp_camera()
		return
	if not _moved: return
	if tab == "hero":
		spin += rel.x * 0.012
		for d in dolls.get_children(): d.rotation.y = spin
		return
	if hold_item >= 0:
		var hit = _floor_hit(p)
		if hit != null:
			var it: Array = S["room"]["items"][hold_item]
			it[1] = hit.x; it[2] = hit.z
			while it.size() < 5: it.append(0.0)
			_clamp_item(it)
			it[4] = room.top_at(it[1], it[2], hold_item) if _small(str(it[0])) else 0.0
			room.place(hold_item, it); _lift_held()
		return
	if win_drag:
		var wh = _wall_hit(p)
		if wh != null:
			var w: Rect2 = Room.win; var np: Vector2 = wh + _win_off
			S["room"]["win"] = [np.x, np.y, w.size.x, w.size.y]
			var nw := Room.win_of(S["room"])
			if nw.position.distance_to(w.position) > 0.04: _refresh_stage()
		return
	if dragging >= 0:
		var hit = _floor_hit(p)
		if hit != null:
			var items: Array = S["room"]["items"]
			items[dragging][1] = hit.x; items[dragging][2] = hit.z
			_clamp_item(items[dragging])
			room.place(dragging, items[dragging])
		return
	cam_yaw -= rel.x * 0.006
	cam_pitch += rel.y * 0.005
	_clamp_camera()

func _p_up(i: int, p: Vector2) -> void:
	touches.erase(i)
	if not touches.is_empty(): return
	if sculpting:
		sculpting = false
		S["hero"]["sculpt"] = dolls.get_child(0).hs.data()
		Data.save_state(S); _refresh_stage()
		return
	hold_cand = -1
	if hold_item >= 0:
		var items: Array = S["room"]["items"]
		var it: Array = items[hold_item]
		var k := _chest_near(it, hold_item)
		if k >= 0 and _small(str(it[0])) and str(it[0]) != "kufr":
			var r: Dictionary = S["room"]
			if not r.has("chest"): r["chest"] = []
			r["chest"].append(str(it[0])); items.remove_at(hold_item)
			Snd.play("trpyt"); room.burst(Vector3(float(items[k if k < hold_item else k - 1][1]), 0.4, float(items[k if k < hold_item else k - 1][2])))
			sel = -1
		else:
			last_moved = hold_item
		hold_item = -1
		Data.save_state(S); _refresh_stage(); paths.build(items); _build_tray()
		return
	if win_drag:
		win_drag = false; Data.save_state(S); _refresh_stage()
		return
	if dragging >= 0:
		dragging = -1; Data.save_state(S); paths.build(S["room"]["items"])
		return
	if not _moved and Time.get_ticks_msec() - _down_time < 600:
		_tap(p)

func _tap(p: Vector2) -> void:
	if window_view:
		_window_tap(p); return
	if tab == "hero": return
	var playing: bool = tab == "friends" or not edit_mode or net.is_client
	if playing:
		var wh = Plane(Vector3(0, 0, 1), -Room.HALF.y + 0.05).intersects_ray(cam.project_ray_origin(p), cam.project_ray_normal(p))
		if wh != null and Room.win.grow(0.1).has_point(Vector2(wh.x, wh.y)):
			_my_cmd(Interact.window())
			return
		var hit = _floor_hit(p)
		if hit == null: return
		var items: Array = current_room()["items"]
		# živá zvířátka jsou jinde než jejich místo: vezmi, kde jsou teď
		for k in items.size():
			if Catalog.get_item(str(items[k][0])).get("live", false):
				var lp: Vector3 = room.live_pos(k)
				items[k][1] = lp.x; items[k][2] = lp.z
		var i := _nearest_item(items, hit)
		if i >= 0: _my_cmd(Interact.at(items, i, people, net.my_id(), cam.global_position))
		else: _my_cmd(Interact.walk(clampf(hit.x, -Room.HALF.x + 0.15, Room.HALF.x - 0.15), clampf(hit.z, -Room.HALF.y + 0.15, Room.HALF.y - 0.15)))
		return
	var hit = _floor_hit(p)
	sel = _nearest_item(S["room"]["items"], hit) if hit != null else -1
	_refresh_stage(); _build_tray()

# ---------- okno a minihra "Co se změnilo?" ----------

const GRIDS := [[2, 2], [3, 2], [3, 3], [4, 3]]

func _enter_window() -> void:
	window_view = true
	var lv := clampi(int(S.get("wlevel", 1)), 1, 4)
	frame.cols = GRIDS[lv - 1][0]; frame.rows = GRIDS[lv - 1][1]
	frame.curtain = 0.0; frame.highlight = -1
	frame.curtain_color = Data.pick(Data.YARN, current_room().get("curt", 0))
	outside.frozen = true
	_refresh_stage(); _build_tray()
	_new_round()

func _leave_window(walk := true) -> void:
	window_view = false
	wg["phase"] = "idle"
	outside.undo(); outside.show_all(); outside.frozen = false
	frame.highlight = -1; frame.curtain = 0.0
	if walk: _my_cmd(Interact.walk(Interact.Room_center_x(), -1.0))

func _new_round() -> void:
	if not window_view: return
	outside.undo()
	outside.set_density(clampi(int(S.get("wlevel", 1)), 1, 4))
	frame.highlight = -1
	wg = {"phase": "look", "pane": -1, "tries": 0, "id": randi()}
	var my_id: int = wg["id"]
	await get_tree().create_timer(2.2).timeout
	if not window_view or wg.get("id") != my_id: return
	wg["phase"] = "close"
	Snd.play("sus")
	var tw := create_tween(); tw.tween_property(frame, "curtain", 1.0, 0.7)
	await tw.finished
	if not window_view or wg.get("id") != my_id: return
	var lv := clampi(int(S.get("wlevel", 1)), 1, 4)
	var panes := range(frame.cols * frame.rows); panes.shuffle()
	for pi in panes:
		if outside.make_change(cam, frame.pane_rect(pi), lv):
			wg["pane"] = pi; break
	await get_tree().create_timer(0.5).timeout
	if not window_view or wg.get("id") != my_id: return
	Snd.play("sus")
	var tw2 := create_tween(); tw2.tween_property(frame, "curtain", 0.0, 0.7)
	await tw2.finished
	if wg.get("id") == my_id: wg["phase"] = "guess"

func _window_tap(p: Vector2) -> void:
	if wg["phase"] != "guess": return
	var pane: int = frame.pane_at(p)
	if pane < 0: return
	if pane == wg["pane"]:
		wg["phase"] = "win"
		frame.highlight = pane
		frame.celebrate(frame.pane_rect(pane).get_center()); Snd.play("hura", 0.0)
		S["stars"] = int(S.get("stars", 0)) + 1; Data.save_state(S)
		_build_tray()
		await get_tree().create_timer(1.6).timeout
		_new_round()
	else:
		wg["tries"] += 1
		frame.flash = pane; frame.flash_t = 0.8; Snd.play("bum")
		if wg["tries"] >= 2:
			wg["phase"] = "show"
			frame.highlight = wg["pane"]
			await get_tree().create_timer(2.2).timeout
			_new_round()

# ---------- pexeso ----------

func _build_overlay() -> void:
	overlay = PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 140; overlay.offset_right = -140; overlay.offset_top = 20; overlay.offset_bottom = -20
	overlay.add_theme_stylebox_override("panel", _box(Color.WHITE, Data.PINK, 6))
	overlay.visible = false
	add_child(overlay)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 30); h.alignment = BoxContainer.ALIGNMENT_CENTER; overlay.add_child(h)
	var grid := GridContainer.new(); grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(grid)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 20); v.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_child(v)
	game_info = Label.new(); game_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_info.custom_minimum_size.x = 260
	game_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(game_info)
	for i in Pexeso.CARDS:
		var c := Card.new(); c.custom_minimum_size = Vector2(150, 150)
		c.tapped.connect(_on_card.bind(i))
		grid.add_child(c); cards.append(c)
	var up := UIcon.new("back", null, Color(0, 0, 0, 0), 110); up.round_btn = true
	up.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	up.tapped.connect(_stand_up); v.add_child(up)

func _on_card(i: int) -> void:
	if net.is_client: net.send_flip(i)
	else: pex.flip(net.my_id(), i)

func _stand_up() -> void:
	var me: int = net.my_id()
	if not doll_nodes.has(me): return
	var p: Vector3 = doll_nodes[me].position.lerp(Vector3(0, 0, 0.6), 0.5)
	_my_cmd(Interact.walk(p.x, p.z))
	overlay.visible = false

func _on_game(st: Dictionary) -> void:
	var me: int = net.my_id()
	if not st.get("active", false) or not (me in st["players"]):
		overlay.visible = false
		return
	overlay.visible = true
	for i in Pexeso.CARDS:
		var c = cards[i]
		c.face = int(st["deck"][i])
		c.matched = st["matched"].has(i)
		c.shown = c.matched or i in st["open"]
		c.queue_redraw()
	var names: Dictionary = st["names"]
	var ps: Array = st["players"]
	var score := "%s %d : %d %s" % [names.get(ps[0], "?"), st["scores"][ps[0]], st["scores"][ps[1]], names.get(ps[1], "?")]
	if st["done"]:
		var a: int = st["scores"][ps[0]]; var b: int = st["scores"][ps[1]]
		var win := "Remíza!" if a == b else "Vyhrává: " + str(names.get(ps[0] if a > b else ps[1], "?")) + "!"
		game_info.text = score + "\n" + win
		if not net.is_client:
			await get_tree().create_timer(4.0).timeout
			if pex.active() and pex.st["done"]:
				var t = pex.st.get("table", -1)
				pex.start(pex.st["players"], pex.st["names"]); pex.st["table"] = t
	else:
		var turn = st["turn"]
		game_info.text = score + "\n" + ("Hraješ ty!" if turn == me else "Hraje: " + str(names.get(turn, "?")))

# ---------- pravý panel ----------

func _clear() -> void:
	for c in tray.get_children(): c.queue_free()
	status_label = null; found_box = null

func _label(t: String, small := false) -> Label:
	var l := Label.new(); l.text = t; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if small: l.add_theme_font_size_override("font_size", 22)
	tray.add_child(l); return l

func _flow(parent: Node = null) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10); flow.add_theme_constant_override("v_separation", 10)
	(parent if parent else tray).add_child(flow); return flow

func _icon(kind: String, cb: Callable, sz := 96.0, parent: Node = null, tex: Texture2D = null, col := Color(0, 0, 0, 0)) -> Control:
	var b := UIcon.new(kind, tex, col, sz)
	b.tapped.connect(cb)
	(parent if parent else tray).add_child(b)
	return b

func _gap() -> void:
	var g := Control.new(); g.custom_minimum_size.y = 6; tray.add_child(g)
	var line := ColorRect.new(); line.color = Data.LILAC; line.custom_minimum_size.y = 3; tray.add_child(line)

## Řada voleb s obrázky (náhledy z icons/opt_<klíč>_<číslo>.png), nebo s barvami.
const LABELS := {"wall": "Barva stěn", "wallp": "Tapeta", "curt": "Závěsy", "floor": "Barva podlahy", "floorp": "Vzor podlahy",
	"hair": "Účes", "hairc": "Barva vlasů", "top": "Oblečení nahoře", "topc": "Barva vršku", "bottom": "Oblečení dole", "botc": "Barva spodku",
	"shoes": "Barva bot", "hat": "Čepice", "hatc": "Barva čepice", "extra": "Brýle, pihy, fousky", "ears": "Uši", "horns": "Růžky",
	"tail": "Ocásek", "wings": "Křídla", "skin": "Barva kůže", "figure": "Postava", "headshape": "Tvar hlavy", "eyes": "Oči",
	"brows": "Obočí", "mouth": "Pusa", "nose": "Nosík", "kkhead": "Hlava", "kkhat": "Klobouk", "kkbody": "Tělo", "kkarms": "Ruce",
	"kklegs": "Nohy", "kkcape": "Plášť", "kktint": "Barva oblečení", "kkhattint": "Barva klobouku", "headw": "Šířka hlavy", "headh": "Výška hlavy"}

func _row_label(t: String) -> void:
	var l := Label.new(); l.text = t
	l.add_theme_font_size_override("font_size", 20); l.add_theme_color_override("font_color", Data.INK.lightened(0.2))
	tray.add_child(l)

func _opt_row(key: String, count: int, target: Dictionary, colors: Array = [], sz := 72.0, textures: Array = []) -> void:
	if LABELS.has(key): _row_label(LABELS[key])
	var flow := _flow()
	for i in count:
		var tex: Texture2D = textures[i] if i < textures.size() else (null if not colors.is_empty() else _opt_tex(key, i))
		var b := UIcon.new("", tex, colors[i] if not colors.is_empty() else Color(0, 0, 0, 0), sz)
		if tex == null and colors.is_empty(): b.text = str(i + 1)
		if key == "wallp" and i == 4: b.text = ""; b.kind = "pencil"
		b.selected = int(target.get(key, 0)) == i
		flow.add_child(b)
		b.tapped.connect(func():
			target[key] = i; Data.save_state(S); _refresh_stage()
			if key == "wallp":
				_build_tray()
				if i == 4: _pixel_studio(target)
				return
			if key == "headshape":
				sculpt_tool = ""
				_clamp_camera(); _build_tray(); return
			for j in flow.get_child_count():
				flow.get_child(j).selected = j == i; flow.get_child(j).queue_redraw())
	_gap()

## Modelína: nástroje pro tvarování vlastní hlavy přímo ve 3D.
func _sculpt_tools(h: Dictionary) -> void:
	var row := _flow()
	for t in [["hand", ""], ["pull", "pull"], ["push", "push"], ["smooth", "smooth"]]:
		var b := _icon(t[0], func(): pass, 72, row)
		b.selected = sculpt_tool == t[1]
		b.tapped.connect(func():
			sculpt_tool = t[1]
			for c in row.get_children(): c.selected = c == b; c.queue_redraw())
	var row2 := _flow()
	var bs := _icon("brush_s" if sculpt_size < 0.4 else "brush_b", func(): pass, 72, row2)
	bs.tapped.connect(func():
		sculpt_size = 0.6 if sculpt_size < 0.4 else 0.3
		bs.kind = "brush_s" if sculpt_size < 0.4 else "brush_b"; bs.queue_redraw())
	var mb := _icon("mirror", func(): pass, 72, row2)
	mb.selected = sculpt_mirror
	mb.tapped.connect(func(): sculpt_mirror = not sculpt_mirror; mb.selected = sculpt_mirror; mb.queue_redraw())
	_icon("reset", func(): h["sculpt"] = []; Data.save_state(S); _refresh_stage(), 72, row2)
	_gap()

## Malování vlastní tapety (25 × 25 čtverečků).
var _pix_dirty := 0
func _pixel_tools(r: Dictionary) -> void:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); tray.add_child(row)
	var prev := TextureRect.new(); prev.custom_minimum_size = Vector2(96, 96); prev.stretch_mode = TextureRect.STRETCH_SCALE
	prev.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prev.texture = PixelEditor.make_texture(r.get("pix", []), Data.pick(Data.WALL, r.get("wall", 0))); row.add_child(prev)
	_icon("pencil", func(): _pixel_studio(r), 96, row)
	_gap()

## Ateliér na malování tapety přes celou obrazovku: velké plátno, lupa, ručička na posouvání.
func _pixel_studio(r: Dictionary) -> void:
	var ov := ColorRect.new(); ov.color = Data.BG; ov.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(ov)
	var mc := MarginContainer.new(); mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]: mc.add_theme_constant_override("margin_" + s, 16)
	ov.add_child(mc)
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 18); mc.add_child(hb)
	var frame_p := PanelContainer.new(); frame_p.add_theme_stylebox_override("panel", _box(Color.WHITE, Data.LILAC, 4))
	frame_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(frame_p)
	var ed := PixelEditor.new()
	if r.get("pix", []).size() > 0: ed.pix = (r["pix"] as Array).duplicate()
	ed.base = Data.pick(Data.WALL, r.get("wall", 0))
	ed.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_p.add_child(ed)
	ed.changed.connect(func(): r["pix"] = ed.pix)
	var side := VBoxContainer.new(); side.custom_minimum_size.x = 330; side.add_theme_constant_override("separation", 10); hb.add_child(side)
	var done := UIcon.new("check", null, Color(0, 0, 0, 0), 84); done.round_btn = true; side.add_child(done)
	done.tapped.connect(func():
		r["pix"] = ed.pix; r["wallp"] = 4; Data.save_state(S); ov.queue_free(); _refresh_stage(); _build_tray())
	var lab := func(t: String):
		var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Data.INK.lightened(0.2)); side.add_child(l)
	lab.call("Barvy")
	var pal := HFlowContainer.new(); pal.add_theme_constant_override("h_separation", 8); pal.add_theme_constant_override("v_separation", 8); side.add_child(pal)
	var tools := HFlowContainer.new(); tools.add_theme_constant_override("h_separation", 8); tools.add_theme_constant_override("v_separation", 8)
	var btn := {}      # tlačítka nástrojů (slovník, ať je lambda vidí i po vytvoření)
	var mark := func():
		for j in pal.get_child_count(): pal.get_child(j).selected = (not ed.hand) and j == ed.brush; pal.get_child(j).queue_redraw()
		if btn.is_empty(): return
		btn["pen"].selected = not ed.hand and ed.brush >= 0; btn["eraser"].selected = not ed.hand and ed.brush < 0; btn["hand"].selected = ed.hand
		for b in btn.values(): b.queue_redraw()
	for k in PixelEditor.PALETTE.size():
		var b := UIcon.new("", null, PixelEditor.PALETTE[k], 50)
		b.tapped.connect(func(): ed.brush = k; ed.hand = false; mark.call())
		pal.add_child(b)
	lab.call("Nástroje")
	side.add_child(tools)
	var pen := UIcon.new("pencil", null, Color(0, 0, 0, 0), 66); tools.add_child(pen)
	pen.tapped.connect(func():
		ed.hand = false
		if ed.brush < 0: ed.brush = 1
		mark.call())
	var eraser := UIcon.new("unpuff", null, Color(0, 0, 0, 0), 66); tools.add_child(eraser)
	eraser.tapped.connect(func(): ed.hand = false; ed.brush = -1; mark.call())
	var handb := UIcon.new("hand", null, Color(0, 0, 0, 0), 66); tools.add_child(handb)
	btn["pen"] = pen; btn["eraser"] = eraser; btn["hand"] = handb
	handb.tapped.connect(func(): ed.hand = true; mark.call())
	for t in [["plus", 1.5], ["minus", 1.0 / 1.5]]:
		var zb := UIcon.new(t[0], null, Color(0, 0, 0, 0), 66); tools.add_child(zb)
		zb.tapped.connect(func(): ed.set_zoom(ed.zoom * float(t[1])))
	var fb := UIcon.new("fill", null, Color(0, 0, 0, 0), 66); tools.add_child(fb); fb.tapped.connect(func(): ed.fill_all())
	var tb := UIcon.new("trash", null, Color(0, 0, 0, 0), 66); tools.add_child(tb); tb.tapped.connect(func(): ed.clear())
	lab.call("Velikost plátna")
	var szr := HBoxContainer.new(); szr.add_theme_constant_override("separation", 10); side.add_child(szr)
	for nn in PixelEditor.SIZES:
		var sb := UIcon.new("", null, Color(0, 0, 0, 0), 76); sb.text = str(nn); szr.add_child(sb)
		sb.selected = ed.n == nn
		sb.tapped.connect(func():
			ed.resize_grid(nn)
			for c in szr.get_children(): c.selected = c == sb; c.queue_redraw())
	mark.call()

## Úpravy míst na hlavě: vyber místo, pak nafoukni / splaskni, protáhni / zkrať, zvětši / zmenši.
func _region_tools(h: Dictionary) -> void:
	var regs := _flow()
	for r in ["brada", "tvare", "celo", "lebka"]:
		var b := _icon("reg_" + r, func(): head_region = r; _build_tray(), 72, regs)
		b.selected = head_region == r
	var acts := _flow()
	var steps := [["puff", "i", 0.08], ["unpuff", "i", -0.08], ["longer", "t", 0.08], ["shorter", "t", -0.08], ["bigger", "s", 0.15], ["smaller", "s", -0.15]]
	var lim := {"i": [-0.4, 0.6], "t": [-0.35, 0.6], "s": [0.5, 1.8]}
	for st in steps:
		var kind: String = st[1]; var step: float = st[2]
		_icon(st[0], func():
			var key := "m_%s_%s" % [head_region, kind]
			h[key] = clampf(float(h.get(key, 1.0 if kind == "s" else 0.0)) + step, lim[kind][0], lim[kind][1])
			Data.save_state(S); _refresh_stage(), 60, acts)
	var reset_row := _flow()
	_icon("reset", func():
		for k in h.keys():
			if str(k).begins_with("m_"): h.erase(k)
		Data.save_state(S); _refresh_stage(), 60, reset_row)
	_gap()

## Posun a velikost očí, nosu, pusy a uší (šipky).
func _tune_rows(h: Dictionary) -> void:
	var rows := [
		["eyes", [["up", "eyes_dy", 0.02], ["down", "eyes_dy", -0.02], ["wider", "eyes_sp", 0.08], ["narrower", "eyes_sp", -0.08], ["bigger", "eyes_s", 0.1], ["smaller", "eyes_s", -0.1]]],
		["nose", [["up", "nose_dy", 0.02], ["down", "nose_dy", -0.02], ["bigger", "nose_s", 0.12], ["smaller", "nose_s", -0.12]]],
		["mouth", [["up", "mouth_dy", 0.02], ["down", "mouth_dy", -0.02], ["bigger", "mouth_s", 0.12], ["smaller", "mouth_s", -0.12]]],
		["ears", [["up", "ears_a", 0.12], ["down", "ears_a", -0.12], ["bigger", "ears_s", 0.12], ["smaller", "ears_s", -0.12]]],
	]
	var limits := {"eyes_dy": [-0.12, 0.12], "nose_dy": [-0.1, 0.1], "mouth_dy": [-0.1, 0.1], "eyes_sp": [0.6, 1.6], "eyes_s": [0.6, 1.7], "nose_s": [0.5, 1.8], "mouth_s": [0.5, 1.8], "ears_a": [-1.0, 1.0], "ears_s": [0.5, 1.7]}
	for r in rows:
		var f := _flow()
		var key: String = r[0]
		var preview := UIcon.new("", _opt_tex(key, int(h.get(key, 0))), Color(0, 0, 0, 0), 64)
		f.add_child(preview)
		for b in r[1]:
			var k: String = b[1]; var step: float = b[2]
			_icon(b[0], func():
				var base := 0.0 if k.ends_with("_dy") or k == "ears_a" else 1.0
				h[k] = clampf(float(h.get(k, base)) + step, limits[k][0], limits[k][1])
				Data.save_state(S); _refresh_stage(), 60, f)
	_gap()

func _view_tex(k: int) -> Texture2D:
	var p := "res://icons/view_%d.png" % k
	return load(p) if ResourceLoader.exists(p) else null

# ---------- jednoduchý editor postavičky ----------
# Jako v dětských hrách: nejdřív hotový kamarád, pak pár velkých záložek s obrázky.

var hero_tab := "kamos"
const HERO_TABS := [["kamos", "tab_kamos"], ["hlava", "tab_hlava"], ["oci", "tab_oci"], ["pusa", "tab_pusa"], ["vlasy", "tab_vlasy"],
	["obleceni", "tab_obleceni"], ["doplnky", "tab_doplnky"], ["telo", "tab_telo"]]
const KK_TABS := [["kamos", "tab_kamos"], ["oci", "tab_oci"], ["doplnky", "tab_doplnky"], ["obleceni", "tab_obleceni"], ["telo", "tab_telo"]]

func _hero_cam() -> void:
	var close: bool = hero_tab in ["oci", "pusa", "vlasy", "hlava"]
	cam_target = Vector3(0, 0.74 if close else 0.55, 0); cam_dist = 2.1 if close else 3.0
	cam_pitch = 0.08

func _cheer() -> void:
	if dolls.get_child_count() == 0: return
	var d = dolls.get_child(0)
	d.command({"act": "wish"}, true)
	Snd.play("trpyt")
	await get_tree().create_timer(1.1).timeout
	if is_instance_valid(d) and tab == "hero": d.command({"act": "idle"}, true)

func _hero_tray(h: Dictionary) -> void:
	var kk := str(h.get("style", "")) == "kk"
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 10); tray.add_child(top)
	_icon("dice", func(): _random_hero(); _refresh_stage(); _build_tray(); _cheer(), 84, top)
	var le := LineEdit.new(); le.text = S["name"]; le.max_length = 14; le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.custom_minimum_size.y = 72
	le.text_changed.connect(func(t): S["name"] = t if t != "" else "Já"; Data.save_state(S))
	top.add_child(le)
	var tabs_f := _flow()
	var list: Array = KK_TABS if kk else HERO_TABS
	var known := false
	for t in list: if t[0] == hero_tab: known = true
	if not known: hero_tab = "kamos"
	for t in list:
		var tb := _icon(t[1], func(): hero_tab = t[0]; _hero_cam(); _build_tray(), 62, tabs_f)
		tb.selected = hero_tab == t[0]
	_gap()
	var pick := func(key: String, n: int, colors: Array = [], sz := 96.0): _opt_row(key, n, h, colors, sz)
	match hero_tab:
		"kamos":
			var pf := _flow()
			var order: Array = Data.BOY_ORDER if Data.theme == "boy" else Data.GIRL_ORDER
			for k in order:
				_icon("", func():
					var keep_name: String = S["name"]
					var p: Dictionary = Data.default_state()["hero"].duplicate()
					p.merge(Data.PRESETS[k], true)
					if not p.has("style"): p["style"] = ""
					S["hero"] = p; S["name"] = keep_name; Data.save_state(S)
					_refresh_stage(); _build_tray(); _cheer(), 92, pf, _opt_tex("preset", k))
		"hlava":
			# tvar hlavy a velká tlačítka: užší / širší / nižší / vyšší
			var sz := _flow()
			for b in [["narrower", "hw", -0.1], ["wider", "hw", 0.1], ["shorter", "hh", -0.1], ["longer", "hh", 0.1]]:
				_icon(b[0], func():
					h[b[1]] = clampf(float(h.get(b[1], 0.5)) + float(b[2]), 0.0, 1.0)
					Data.save_state(S); _refresh_stage(), 74, sz)
			_icon("reset", func(): h["hw"] = 0.5; h["hh"] = 0.5; Data.save_state(S); _refresh_stage(), 74, sz)
			_gap()
			pick.call("headshape", Data.OPT["headshape"].size())
			pick.call("ears", Data.OPT["ears"].size())
		"oci":
			if kk: pick.call("kkhead", KKDoll.names("kkhead"))
			else:
				pick.call("eyes", Data.OPT["eyes"].size())
				pick.call("brows", Data.OPT["brows"].size())
		"pusa":
			pick.call("mouth", Data.OPT["mouth"].size())
			pick.call("nose", Data.OPT["nose"].size())
		"vlasy":
			pick.call("hair", Data.OPT["hair"].size())
			pick.call("hairc", Data.HAIRC.size(), Data.HAIRC, 60)
		"obleceni":
			if kk:
				pick.call("kkbody", KKDoll.names("kkbody"))
				pick.call("kktint", KKDoll.TINT.size(), KKDoll.TINT, 60)
				pick.call("kkcape", KKDoll.names("kkcape"))
			else:
				pick.call("top", Data.OPT["top"].size())
				pick.call("topc", Data.YARN.size(), Data.YARN, 60)
				pick.call("bottom", Data.OPT["bottom"].size())
				pick.call("botc", Data.YARN.size(), Data.YARN, 60)
				pick.call("shoes", Data.YARN.size(), Data.YARN, 60)
		"doplnky":
			if kk:
				pick.call("kkhat", KKDoll.names("kkhat"))
				pick.call("kkhattint", KKDoll.TINT.size(), KKDoll.TINT, 60)
			else:
				pick.call("hat", Data.OPT["hat"].size())
				pick.call("hatc", Data.YARN.size(), Data.YARN, 60)
				pick.call("extra", Data.OPT["extra"].size())
				pick.call("horns", Data.OPT["horns"].size())
				pick.call("tail", Data.OPT["tail"].size())
				pick.call("wings", Data.OPT["wings"].size())
		"telo":
			if kk:
				pick.call("kkarms", KKDoll.names("kkarms"))
				pick.call("kklegs", KKDoll.names("kklegs"))
			else:
				pick.call("skin", Data.SKIN.size(), Data.SKIN, 60)
				pick.call("figure", Data.OPT["figure"].size())
		"nastroje":
			_opt_row("headw", 5, h, [], 72)
			_opt_row("headh", 5, h, [], 72)

func _new_doll(h: Dictionary) -> Node3D:
	return KKDoll.new() if str(h.get("style", "")) == "kk" else Doll.new()

func _opt_tex(key: String, i: int) -> Texture2D:
	var p := "res://icons/opt_%s_%d.png" % [key, i]
	return load(p) if ResourceLoader.exists(p) else null

func _upd_text() -> void:
	if not is_instance_valid(upd_label): return
	upd_label.text = {"checking": "Hledám novou verzi…", "downloading": "Stahuji novou verzi…",
		"done": "Hotovo! Ťukni znovu a hra se spustí v nové verzi.", "latest": "Máš nejnovější verzi.",
		"apk": "Je potřeba nová instalace – ťukni a stáhne se.", "error": "Nepovedlo se připojit. Je zapnutý internet?"}.get(_upd_state, "Ťukni na mráček a hra se aktualizuje.")

func _set_row(kind_on: String, kind_off: String, title: String, on: bool, vol: float, toggle: Callable, setvol: Callable) -> void:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); tray.add_child(row)
	var b := UIcon.new(kind_on if on else kind_off, null, Color(0, 0, 0, 0), 76); row.add_child(b)
	b.tapped.connect(func():
		var now: bool = toggle.call(); b.kind = kind_on if now else kind_off; b.queue_redraw())
	var col := VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(col)
	var l := Label.new(); l.text = title; l.add_theme_font_size_override("font_size", 24); col.add_child(l)
	var sl := HSlider.new(); sl.min_value = 0; sl.max_value = 1; sl.step = 0.05; sl.value = vol
	sl.custom_minimum_size = Vector2(0, 40); sl.value_changed.connect(setvol); col.add_child(sl)

## Holčičí nebo klučičí vzhled. Poprvé se vybírá velkými obrázky bez textu.
func _set_theme(t: String) -> void:
	var fresh: bool = S["hero"] == Data.default_state()["hero"]
	S["theme"] = t
	if fresh:
		var p: Dictionary = Data.default_state()["hero"].duplicate()
		p.merge(Data.PRESETS[3 if t == "boy" else 0], true)
		S["hero"] = p
		if t == "boy" and int(S["room"].get("wallp", 2)) == 2:
			S["room"]["wall"] = 1; S["room"]["wallp"] = 8; S["room"]["floor"] = 0
	Data.save_state(S)
	get_tree().reload_current_scene()

func _theme_picker() -> void:
	var ov := ColorRect.new(); ov.color = Color(1, 1, 1, 0.92); ov.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(ov)
	var hb := HBoxContainer.new(); hb.set_anchors_preset(Control.PRESET_CENTER); hb.add_theme_constant_override("separation", 80)
	hb.position = Vector2(-300, -150); ov.add_child(hb)
	for t in [["girl", 0], ["boy", 3]]:
		var b := UIcon.new("", _opt_tex("preset", t[1]), Color(0, 0, 0, 0), 260); b.round_btn = true
		b.tapped.connect(func(): _set_theme(t[0])); hb.add_child(b)

func _settings_tray() -> void:
	var t := _label("Nastavení"); t.add_theme_font_size_override("font_size", 34)
	_set_row("music", "mute", "Hudba", Snd.music_on, float(S.get("mvol", 0.7)),
		func(): S["music"] = not Snd.music_on; Snd.set_music(S["music"]); Data.save_state(S); return Snd.music_on,
		func(v: float): S["mvol"] = v; Snd.set_volumes(v, float(S.get("svol", 0.9))); Data.save_state(S))
	_set_row("sound", "nosound", "Zvuky", Snd.sfx_on, float(S.get("svol", 0.9)),
		func(): Snd.sfx_on = not Snd.sfx_on; S["sfx"] = Snd.sfx_on; Data.save_state(S); return Snd.sfx_on,
		func(v: float): S["svol"] = v; Snd.set_volumes(float(S.get("mvol", 0.7)), v); Data.save_state(S); Snd.play("pop", 0.0))
	_gap()
	var vl := _label("Vzhled"); vl.add_theme_font_size_override("font_size", 26)
	var th := _flow()
	for tt in [["girl", 0], ["boy", 3]]:
		var tb := _icon("", func(): _set_theme(tt[0]), 96, th, _opt_tex("preset", tt[1]))
		tb.selected = Data.theme == tt[0]
	_gap()
	var a := _label("O aplikaci"); a.add_theme_font_size_override("font_size", 30)
	_label("Můj Pokojíček\nverze %s · obsah %d" % ["0.7", updater.CONTENT], true)
	var urow := HBoxContainer.new(); urow.add_theme_constant_override("separation", 12); tray.add_child(urow)
	upd_btn = UIcon.new("update", null, Color(0, 0, 0, 0), 84); upd_btn.round_btn = true
	upd_btn.tapped.connect(_on_update_tap); urow.add_child(upd_btn)
	upd_label = Label.new(); upd_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upd_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; upd_label.add_theme_font_size_override("font_size", 22); urow.add_child(upd_label)
	if _upd_state != "": _on_update_status(_upd_state, _apk_url)
	else: _upd_text()
	_gap()
	_label("Pro rodiče: hra funguje bez internetu, kamarádi se připojují přes stejnou wifi. Žádné reklamy ani nákupy.", true)
	_label("Poděkování: 3D modely KayKit (CC0), hudba HoliznaCC0, Komiku, Loyalty Freak Music a John Bartmann (CC0), zvuky Kenney a freesound.org (CC0), zvířátka Gobkit (CC0).", true)

func _build_tray() -> void:
	_clear()
	if settings_open:
		_settings_tray(); return
	if window_view and tab != "hero":
		var top := HBoxContainer.new(); tray.add_child(top)
		_icon("back", func(): _leave_window(); _refresh_stage(); _build_tray(), 96, top)
		var star := UIcon.new("star", null, Color(0, 0, 0, 0), 96); top.add_child(star)
		var cnt := Label.new(); cnt.text = str(int(S.get("stars", 0))); cnt.add_theme_font_size_override("font_size", 44)
		cnt.add_theme_color_override("font_color", Color("ffb020")); top.add_child(cnt)
		_gap()
		_row_label("Kolik věcí venku")
		var lv := _flow()
		for k in 4:
			var b := _icon("few%d" % (k + 1), func():
				S["wlevel"] = k + 1; Data.save_state(S)
				frame.cols = GRIDS[k][0]; frame.rows = GRIDS[k][1]
				_build_tray(); _new_round(), 96, lv)
			b.selected = int(S.get("wlevel", 1)) == k + 1
		_gap()
		_row_label("Výhled z okna")
		var vf := _flow()
		for k in Outside.VIEWS.size():
			var vb := _icon("", func():
				S["view"] = k; Data.save_state(S); outside.set_view(k); outside.apply_sky()
				for c in vf.get_children(): c.selected = false
				vf.get_child(k).selected = true
				_new_round(), 84, vf, _view_tex(k))
			vb.selected = k == int(S.get("view", 0))
		_gap()
		_row_label("Počasí")
		var wf := _flow()
		for k in Data.WEATHER.size():
			var w := WIcon.new(); w.kind = k; w.selected = k == int(S.get("weather", 0))
			w.custom_minimum_size = Vector2(96, 96)
			w.tapped.connect(func():
				S["weather"] = k; Data.save_state(S); outside.set_weather(k)
				for c in wf.get_children(): c.selected = c.kind == k; c.queue_redraw()
				_new_round())
			wf.add_child(w)
		return
	match tab:
		"hero":
			_hero_tray(S["hero"])
		"room":
			var rr: Dictionary = S["room"]
			if chest_open >= 0 and not net.is_client and chest_open < rr["items"].size() and str(rr["items"][chest_open][0]) == "kufr":
				var hb := _flow()
				_icon("back", func(): chest_open = -1; _build_tray(), 80, hb)
				_icon("", func(): pass, 80, hb, Catalog.icon("kufr"))
				_gap()
				var cf := _flow()
				var stored: Array = rr.get("chest", [])
				for k in stored.size():
					var sid: String = stored[k]
					_icon("", func():
						var ch: Array = rr["items"][chest_open]
						rr["items"].append([sid, clampf(float(ch[1]) + randf_range(-0.4, 0.4), -3.2, 3.2), clampf(float(ch[2]) + 0.45, -1.9, 1.9), 0])
						stored.remove_at(k); Snd.play("pop"); Data.save_state(S); _refresh_stage(); paths.build(rr["items"]); _build_tray(), 84, cf, Catalog.icon(sid))
				_gap()
			if net.is_client or not edit_mode:
				var f := _flow()
				_icon("window", func(): _my_cmd(Interact.window()), 110, f)
				if not net.is_client and last_moved >= 0 and last_moved < rr["items"].size():
					_icon("rotate", func(): _rotate_item(last_moved), 110, f)
				return
			var r: Dictionary = S["room"]
			if sel >= 0:
				var row2 := HBoxContainer.new(); row2.add_theme_constant_override("separation", 10); tray.add_child(row2)
				_icon("rotate", func(): _rotate_item(sel), 96, row2)
				_icon("trash", func(): r["items"].remove_at(sel); sel = -1; Data.save_state(S); _refresh_stage(); _build_tray(), 96, row2)
				_gap()
			_row_label("Vyber věc a přetáhni ji do pokojíčku")
			var cats := _flow()
			for c in Catalog.CATS:
				var cb := _icon("", func(): cat = c[0]; _build_tray(), 72, cats, Catalog.icon(Catalog.in_cat(c[0])[0]))
				cb.selected = c[0] == cat
			_gap()
			var flow := _flow()
			for id in Catalog.in_cat(cat):
				# každá věc může být v pokojíčku jen jednou: podruhé ji jen vybereme (nebo vyndáme z kufru)
				var have := -1
				for j in r["items"].size():
					if str(r["items"][j][0]) == id: have = j; break
				var in_chest: bool = r.get("chest", []).has(id)
				var ib := _icon("", func():
					if have >= 0:
						sel = have; Snd.play("cink")
					else:
						if in_chest: r["chest"].erase(id)
						r["items"].append([id, randf_range(-0.6, 0.6), randf_range(-0.2, 0.6), 0])
						sel = r["items"].size() - 1
					Data.save_state(S); _refresh_stage(); _build_tray(), 96, flow, Catalog.icon(id))
				ib.selected = have >= 0
				ib.draggable = true
				ib.drag_out.connect(func(_at): _start_drag_new(id))
				if have >= 0 or in_chest: ib.modulate = Color(1, 1, 1, 0.55)
			_gap()
			_opt_row("wall", Data.WALL.size(), r, Data.WALL, 64)
			var wt := []
			for k in 4: wt.append(Room.pattern_mat(Data.pick(Data.WALL, r.get("wall", 0)), k, false).albedo_texture)
			wt.append(null)
			for k in Data.MURALS.size(): wt.append(Room.mural_tex(k))
			_opt_row("wallp", Data.WALLP.size(), r, [], 84, wt)
			if int(r.get("wallp", 0)) == 4: _pixel_tools(r)
			_opt_row("curt", Data.YARN.size(), r, Data.YARN, 56)
			_row_label("Velikost okna")
			var wf2 := _flow()
			_icon("wider", func(): _win_size(0.3, 0), 64, wf2)
			_icon("narrower", func(): _win_size(-0.3, 0), 64, wf2)
			_icon("longer", func(): _win_size(0, 0.2), 64, wf2)
			_icon("shorter", func(): _win_size(0, -0.2), 64, wf2)
			_gap()
			_opt_row("floor", Data.FLOOR.size(), r, Data.FLOOR, 64)
			var ft := []
			for k in Data.FLOORP.size(): ft.append(Room.pattern_mat(Data.pick(Data.FLOOR, r.get("floor", 0)), k, true).albedo_texture)
			_opt_row("floorp", Data.FLOORP.size(), r, [], 84, ft)
		"friends":
			var f := _flow()
			_icon("invite", func(): _go_home(); net.open_room(S); _people_reset(); _refresh_stage(), 110, f)
			_icon("search", func(): _go_home(); found_ips.clear(); net.search(); _build_found(), 110, f)
			_icon("home", func(): _go_home(); if status_label: status_label.text = "", 110, f)
			status_label = _label("", true)
			found_box = VBoxContainer.new(); found_box.add_theme_constant_override("separation", 10); tray.add_child(found_box)
			_build_found()
			_gap()
			_label("IP: " + Net.my_ip(), true)
			var row := HBoxContainer.new(); tray.add_child(row)
			var ip := LineEdit.new(); ip.placeholder_text = "192.168.…"; ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ip.custom_minimum_size.y = 80
			row.add_child(ip)
			_icon("play", func(): net.visit(ip.text.strip_edges(), S), 80, row)

func _random_hero() -> void:
	var h: Dictionary = S["hero"]
	for k in Data.OPT: h[k] = randi() % Data.OPT[k].size()
	h["skin"] = randi() % Data.SKIN.size(); h["hairc"] = randi() % Data.HAIRC.size()
	for k in ["topc", "botc", "shoes", "hatc"]: h[k] = randi() % Data.YARN.size()
	# ať to není moc přeplácané: rohy, ocásek, křídla jen občas
	for k in ["horns", "tail", "wings", "extra"]:
		if randf() < 0.5: h[k] = 0
	for k in ["kkhead", "kkbody", "kkarms", "kklegs", "kkhat", "kkcape", "kktint", "kkhattint"]: h[k] = randi() % KKDoll.names(k)
	if randf() < 0.4: h["kkhat"] = 0
	if randf() < 0.4: h["kkcape"] = 0
	Data.save_state(S)

func _on_found(n: String, ip: String) -> void:
	if found_ips.has(ip): return
	found_ips[ip] = n
	_build_found()

func _build_found() -> void:
	if not found_box: return
	for c in found_box.get_children(): c.queue_free()
	for ip in found_ips:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); found_box.add_child(row)
		_icon("face", func(): net.visit(ip, S), 96, row)
		var l := Label.new(); l.text = found_ips[ip]; row.add_child(l)

func _box(fill: Color, border: Color, bw := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new(); sb.bg_color = fill; sb.border_color = border
	sb.set_border_width_all(bw); sb.set_corner_radius_all(24)
	sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 12; sb.content_margin_bottom = 12
	return sb

func _make_theme() -> Theme:
	var t := Theme.new(); t.default_font_size = 30
	var n := _box(Color.WHITE, Data.LILAC)
	for st in ["normal", "focus", "read_only"]:
		t.set_stylebox(st, "LineEdit", n)
	t.set_color("font_color", "Label", Data.INK); t.set_color("font_color", "LineEdit", Data.INK)
	return t
