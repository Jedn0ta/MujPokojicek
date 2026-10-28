class_name Interact
## Co panenka udělá u které věci. Vrací příkaz pro panenku:
## ax, az = kam dojde · px, pz, ry = kde a jak natočená skončí · act = co udělá.
## Druh akce bere z katalogu (catalog.gd), takže nová věc nepotřebuje nový kód.

static func _taken(people: Dictionary, me: int, i: int, seat: int) -> bool:
	for id in people:
		var o: Dictionary = people[id].get("cmd", {})
		if id != me and o.get("act") in ["sit", "game"] and int(o.get("item", -1)) == i and int(o.get("seat", -1)) == seat:
			return true
	return false

static func at(items: Array, i: int, people: Dictionary, me: int) -> Dictionary:
	var it: Array = items[i]
	var e := Catalog.get_item(str(it[0]))
	var p := Vector3(float(it[1]), 0, float(it[2]))
	var ry := deg_to_rad(float(it[3]) if it.size() > 3 else 0.0)
	var b := Basis(Vector3.UP, ry)
	var front := p + b * Vector3(0, 0, float(e["d"]) / 2.0 + 0.22)   # místo před věcí
	var c := {"item": i, "act": e["act"], "ax": front.x, "az": front.z, "px": front.x, "pz": front.z, "ry": ry + PI}
	match str(e["act"]):
		"game":
			var k := 1 if _taken(people, me, i, 0) else 0
			var seat := p + b * Vector3(0, 0, 0.45 if k == 0 else -0.45)
			c.merge({"act": "sit", "seat": k, "ax": seat.x, "az": seat.z, "px": seat.x, "pz": seat.z, "ry": ry + (PI if k == 0 else 0.0)}, true)
		"sit":
			var seats: Array = e.get("seats", [0.0])
			var k := 0
			for s in seats.size():
				if not _taken(people, me, i, s): k = s; break
			var seat := p + b * Vector3(float(seats[k]), 0, 0.03)
			var walk_to := p + b * Vector3(float(seats[k]), 0, float(e["d"]) / 2.0 + 0.2)
			c.merge({"seat": k, "ax": walk_to.x, "az": walk_to.z, "px": seat.x, "pz": seat.z, "ry": ry}, true)
		"bath":
			var side := p + b * Vector3(0, 0, float(e["d"]) / 2.0 + 0.25)
			c.merge({"ax": side.x, "az": side.z, "px": p.x, "pz": p.z, "ry": ry}, true)
		"toilet":
			var walk_to := p + b * Vector3(0, 0, 0.35)
			c.merge({"ax": walk_to.x, "az": walk_to.z, "px": p.x, "pz": p.z + 0.02, "ry": ry}, true)
		"draw":
			var near := p + b * Vector3(0, 0, -0.22)
			c.merge({"ax": near.x, "az": near.z, "px": near.x, "pz": near.z, "ry": ry}, true)
		"lie":
			var side := p + b * Vector3(float(e["w"]) / 2.0 + 0.25, 0, 0)
			c.merge({"ax": side.x, "az": side.z, "px": p.x, "pz": p.z, "ry": ry}, true)
		"dance":
			c.merge({"ax": p.x, "az": p.z, "px": p.x, "pz": p.z, "ry": ry}, true)
		"play":
			if e["file"] == "":
				var near := p + b * Vector3(0, 0, 0.25)
				c.merge({"ax": near.x, "az": near.z, "px": near.x, "pz": near.z}, true)
		"kick":
			var to := Vector3(clampf(p.x + randf_range(-1.2, 1.2), -2.3, 2.3), 0, clampf(p.z - randf_range(0.6, 1.2), -1.8, 1.8))
			c.merge({"bx": to.x, "bz": to.z}, true)
	return c

static func walk(x: float, z: float) -> Dictionary:
	return {"act": "idle", "ax": x, "az": z, "px": x, "pz": z}

## K oknu: panenka dojde k oknu a kouká ven.
static func window() -> Dictionary:
	var x := Room_center_x()
	return {"act": "window", "ax": x, "az": -1.55, "px": x, "pz": -1.55, "ry": PI}

static func Room_center_x() -> float:
	return -0.35 + 1.1 / 2.0
