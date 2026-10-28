extends Node
## Pexeso pro dva hráče. Běží jen u hostitele (nebo offline); ostatní dostávají stav.
## Hráč -1 je počítač.

signal changed(state: Dictionary)

const CARDS := 16
var st: Dictionary = {}
var busy := false

func active() -> bool:
	return st.get("active", false)

func start(players: Array, names: Dictionary) -> void:
	var deck := []
	for k in CARDS / 2:
		deck.append(k); deck.append(k)
	deck.shuffle()
	st = {"active": true, "deck": deck, "open": [], "matched": {}, "turn": players[0],
		"players": players, "names": names, "scores": {}, "done": false}
	for p in players: st["scores"][p] = 0
	busy = false
	changed.emit(st)
	_computer()

func stop() -> void:
	if active():
		st["active"] = false
		changed.emit(st)

func flip(pid: int, i: int) -> void:
	if not active() or st["done"] or busy or pid != st["turn"]: return
	if i < 0 or i >= CARDS or st["matched"].has(i) or i in st["open"]: return
	st["open"].append(i)
	changed.emit(st)
	if st["open"].size() < 2: return
	busy = true
	await get_tree().create_timer(1.0).timeout
	if not active(): return
	var a: int = st["open"][0]
	var b: int = st["open"][1]
	if st["deck"][a] == st["deck"][b]:
		st["matched"][a] = pid; st["matched"][b] = pid
		st["scores"][pid] += 1
	else:
		var ps: Array = st["players"]
		st["turn"] = ps[(ps.find(pid) + 1) % ps.size()]
	st["open"] = []
	busy = false
	if st["matched"].size() == CARDS: st["done"] = true
	changed.emit(st)
	_computer()

func _computer() -> void:
	if not active() or st["done"] or st["turn"] != -1: return
	await get_tree().create_timer(0.8).timeout
	if not active() or st["turn"] != -1 or busy: return
	var free := []
	for i in CARDS:
		if not st["matched"].has(i) and not (i in st["open"]): free.append(i)
	if free.is_empty(): return
	flip(-1, free.pick_random())
	_computer()
