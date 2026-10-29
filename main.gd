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
var tray_scroll: ScrollContainer
var overlay: PanelContainer
var game_info: Label
var cards: Array = []

func _ready() -> void:
	S = Data.load_state()
	theme = _make_theme()
	var bg := ColorRect.new(); bg.color = Data.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var m := MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + side, 14)
	add_child(m)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 14); m.add_child(row)
	var left := VBoxContainer.new(); left.add_theme_constant_override("separation", 16); row.add_child(left)
	for t in ["hero", "room", "friends"]:
		var b := UIcon.new({"hero": "doll", "room": "house", "friends": "friends"}[t], null, Color(0, 0, 0, 0), 96)
		b.round_btn = true
		b.tapped.connect(_set_tab.bind(t)); left.add_child(b); tabs[t] = b
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; left.add_child(spacer)
	upd_btn = UIcon.new("update", null, Color(0, 0, 0, 0), 80); upd_btn.round_btn = true
	upd_btn.tapped.connect(_on_update_tap); left.add_child(upd_btn)
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

func _build_world(vp: SubViewport) -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color("ffe9f3")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff4fb"); env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-60, 25, 0)
	sun.light_energy = 0.25; sun.shadow_enabled = true; vp.add_child(sun)
	cam = Camera3D.new(); vp.add_child(cam)
	room = Room.new(); vp.add_child(room)
	pedestal = Node3D.new(); vp.add_child(pedestal)
	Yarn.cyl(pedestal, Vector3(0, -0.03, 0), 0.45, 0.5, 0.06, Color("cdbcff"))
	dolls = Node3D.new(); vp.add_child(dolls)
	outside = Outside.new(); outside.position = OUT; outside.env = env; outside.sun = sun
	vp.add_child(outside); outside.build()
	outside.set_weather(int(S.get("weather", 0)), false)

var _heart_t := 0.0
func _process(d: float) -> void:
	if _pix_dirty > 0 and Time.get_ticks_msec() > _pix_dirty:
		_pix_dirty = 0; Data.save_state(S); room.build(current_room(), sel if edit_mode else -1)
	_bump_small_things()
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
	if _upd_state == "downloading":
		upd_btn.progress = max(0.02, updater.progress()); upd_btn.queue_redraw()

# ---------- kamera ----------

func _cam_defaults() -> void:
	if tab == "hero":
		cam_target = Vector3(0, 0.55, 0); cam_yaw = 0.0; cam_pitch = 0.08; cam_dist = 3.0
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
		cam.look_at(OUT + Vector3(0, 1.9, -6))
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
	match str(c.get("act", "")):
		"kick":
			if i >= 0 and i < items.size():
				items[i][1] = c["bx"]; items[i][2] = c["bz"]
				room.move_item(i, Vector3(float(c["bx"]), 0, float(c["bz"])))
		"lamp":
			room.toggle_lamp(i)
		"open":
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
		var d := Doll.new(); dolls.add_child(d); d.build(S["hero"]); d.rotation.y = spin
		return
	room.visible = true; pedestal.visible = false
	room.build(current_room(), sel if tab == "room" and edit_mode else -1)
	paths.build(current_room()["items"])
	var ids := people.keys()
	for k in ids.size():
		var id: int = ids[k]
		var d := Doll.new(); dolls.add_child(d); d.build(people[id]["data"].get("hero", {}))
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

func _p_down(i: int, p: Vector2) -> void:
	touches[i] = p
	if touches.size() == 1:
		_down_pos = p; _down_time = Time.get_ticks_msec(); _moved = false
		dragging = -1
		if tab == "hero" and sculpt_tool != "" and int(S["hero"].get("headshape", 0)) == HeadShape.CUSTOM and dolls.get_child_count() > 0:
			var hit = dolls.get_child(0).sculpt_ray(cam.project_ray_origin(p), cam.project_ray_normal(p))
			if hit != null:
				sculpting = true; _moved = true
				dolls.get_child(0).sculpt_brush(hit, sculpt_tool, sculpt_size, sculpt_mirror)
				return
		if tab == "room" and edit_mode and not net.is_client and not window_view:
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
	if sculpting:
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
	if dragging >= 0:
		var hit = _floor_hit(p)
		if hit != null:
			var items: Array = S["room"]["items"]
			items[dragging][1] = clampf(hit.x, -Room.HALF.x + 0.15, Room.HALF.x - 0.15)
			items[dragging][2] = clampf(hit.z, -Room.HALF.y + 0.15, Room.HALF.y - 0.15)
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
		if wh != null and Room.WINDOW.grow(0.1).has_point(Vector2(wh.x, wh.y)):
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
		frame.celebrate(frame.pane_rect(pane).get_center())
		S["stars"] = int(S.get("stars", 0)) + 1; Data.save_state(S)
		_build_tray()
		await get_tree().create_timer(1.6).timeout
		_new_round()
	else:
		wg["tries"] += 1
		frame.flash = pane; frame.flash_t = 0.8
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
func _opt_row(key: String, count: int, target: Dictionary, colors: Array = [], sz := 72.0, textures: Array = []) -> void:
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
			if key == "wallp": _build_tray(); return
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
	var ed := PixelEditor.new()
	if r.get("pix", []).size() == PixelEditor.N * PixelEditor.N: ed.pix = r["pix"]
	ed.base = Data.pick(Data.WALL, r.get("wall", 0))
	ed.changed.connect(func(): r["pix"] = ed.pix; _pix_dirty = Time.get_ticks_msec() + 250)
	var pal := _flow()
	for k in PixelEditor.PALETTE.size():
		var b := UIcon.new("", null, PixelEditor.PALETTE[k], 50)
		b.selected = k == ed.brush
		b.tapped.connect(func():
			ed.brush = k
			for j in pal.get_child_count(): pal.get_child(j).selected = j == k; pal.get_child(j).queue_redraw())
		pal.add_child(b)
	tray.add_child(ed)
	var tools := _flow()
	_icon("fill", func(): ed.fill_all(), 64, tools)
	_icon("trash", func(): ed.clear(), 64, tools)
	_gap()

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

func _opt_tex(key: String, i: int) -> Texture2D:
	var p := "res://icons/opt_%s_%d.png" % [key, i]
	return load(p) if ResourceLoader.exists(p) else null

func _build_tray() -> void:
	_clear()
	if window_view and tab != "hero":
		var top := HBoxContainer.new(); tray.add_child(top)
		_icon("back", func(): _leave_window(); _refresh_stage(); _build_tray(), 96, top)
		var star := UIcon.new("star", null, Color(0, 0, 0, 0), 96); top.add_child(star)
		var cnt := Label.new(); cnt.text = str(int(S.get("stars", 0))); cnt.add_theme_font_size_override("font_size", 44)
		cnt.add_theme_color_override("font_color", Color("ffb020")); top.add_child(cnt)
		_gap()
		var lv := _flow()
		for k in 4:
			var b := _icon("few%d" % (k + 1), func():
				S["wlevel"] = k + 1; Data.save_state(S)
				frame.cols = GRIDS[k][0]; frame.rows = GRIDS[k][1]
				_build_tray(); _new_round(), 96, lv)
			b.selected = int(S.get("wlevel", 1)) == k + 1
		_gap()
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
			var h: Dictionary = S["hero"]
			var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 10); tray.add_child(top)
			_icon("dice", func(): _random_hero(); _refresh_stage(); _build_tray(), 96, top)
			var le := LineEdit.new(); le.text = S["name"]; le.max_length = 14; le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			le.custom_minimum_size.y = 80
			le.text_changed.connect(func(t): S["name"] = t if t != "" else "Já"; Data.save_state(S))
			top.add_child(le)
			_gap()
			_opt_row("headshape", Data.OPT["headshape"].size(), h)
			_opt_row("headw", 5, h, [], 72)
			_opt_row("headh", 5, h, [], 72)
			_opt_row("headd", 3, h, [], 72)
			_region_tools(h)
			_opt_row("skin", Data.SKIN.size(), h, Data.SKIN, 56)
			_opt_row("eyes", Data.OPT["eyes"].size(), h)
			_opt_row("brows", Data.OPT["brows"].size(), h)
			_opt_row("nose", Data.OPT["nose"].size(), h)
			_opt_row("mouth", Data.OPT["mouth"].size(), h)
			_opt_row("extra", Data.OPT["extra"].size(), h)
			_tune_rows(h)
			_opt_row("hair", Data.OPT["hair"].size(), h)
			_opt_row("hairc", Data.HAIRC.size(), h, Data.HAIRC, 56)
			_opt_row("ears", Data.OPT["ears"].size(), h)
			_opt_row("horns", Data.OPT["horns"].size(), h)
			_opt_row("hat", Data.OPT["hat"].size(), h)
			_opt_row("hatc", Data.YARN.size(), h, Data.YARN, 56)
			_opt_row("figure", Data.OPT["figure"].size(), h)
			_opt_row("top", Data.OPT["top"].size(), h)
			_opt_row("topc", Data.YARN.size(), h, Data.YARN, 56)
			_opt_row("bottom", Data.OPT["bottom"].size(), h)
			_opt_row("botc", Data.YARN.size(), h, Data.YARN, 56)
			_opt_row("shoes", Data.YARN.size(), h, Data.YARN, 56)
			_opt_row("tail", Data.OPT["tail"].size(), h)
			_opt_row("wings", Data.OPT["wings"].size(), h)
		"room":
			if net.is_client or not edit_mode:
				var f := _flow()
				_icon("window", func(): _my_cmd(Interact.window()), 110, f)
				return
			var r: Dictionary = S["room"]
			if sel >= 0:
				var row2 := HBoxContainer.new(); row2.add_theme_constant_override("separation", 10); tray.add_child(row2)
				_icon("rotate", func(): var it: Array = r["items"][sel]; it[3] = fmod(float(it[3]) + 90.0, 360.0); room.place(sel, it); Data.save_state(S); paths.build(r["items"]), 96, row2)
				_icon("trash", func(): r["items"].remove_at(sel); sel = -1; Data.save_state(S); _refresh_stage(); _build_tray(), 96, row2)
				_gap()
			var cats := _flow()
			for c in Catalog.CATS:
				var cb := _icon("", func(): cat = c[0]; _build_tray(), 72, cats, Catalog.icon(Catalog.in_cat(c[0])[0]))
				cb.selected = c[0] == cat
			_gap()
			var flow := _flow()
			for id in Catalog.in_cat(cat):
				_icon("", func():
					r["items"].append([id, randf_range(-0.6, 0.6), randf_range(-0.2, 0.6), 0])
					sel = r["items"].size() - 1
					Data.save_state(S); _refresh_stage(); _build_tray(), 96, flow, Catalog.icon(id))
			_gap()
			_opt_row("wall", Data.WALL.size(), r, Data.WALL, 64)
			var wt := []
			for k in Data.WALLP.size(): wt.append(Room.pattern_mat(Data.pick(Data.WALL, r.get("wall", 0)), k, false).albedo_texture)
			wt.append(null)
			_opt_row("wallp", Data.WALLP.size(), r, [], 84, wt)
			if int(r.get("wallp", 0)) == 4: _pixel_tools(r)
			_opt_row("curt", Data.YARN.size(), r, Data.YARN, 56)
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
