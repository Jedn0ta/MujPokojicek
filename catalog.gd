class_name Catalog
## Všechno, co jde dát do pokoje. Modely jsou z bezplatných balíčků KayKit (CC0),
## hračky jsou poskládané v kódu (room.gd). Rozměry w, d jsou v metrech hry po zmenšení.
##
## act: co panenka udělá · seats: místa k sezení · lift: výška nad zemí (věci na zeď)

const CATS := [
	["postele", "Postele"], ["sezeni", "Sezení"], ["stoly", "Stoly"], ["skrine", "Skříně"],
	["svetla", "Světla"], ["koberce", "Koberce"], ["kytky", "Kytky"], ["dekorace", "Obrázky"],
	["kuchyn", "Kuchyňka"], ["hracky", "Hračky"], ["zviratka", "Zvířátka"], ["dobroty", "Dobroty"],
	["zdrave", "Ovoce a zelenina"], ["darky", "Dárky a hvězdičky"], ["pece", "Péče a návyky"],
]
const F := 0.5    # zmenšení nábytku
const K := 0.42   # zmenšení kuchyňky
const J := 0.25   # zmenšení jídla

# id, kategorie, soubor (prázdný = hračka z kódu), zmenšení, akce, šířka, hloubka, další
const RAW := [
	["postel1", "postele", "furniture/bed_single_A", F, "lie", 0.8, 1.5, {}],
	["postel2", "postele", "furniture/bed_single_B", F, "lie", 0.8, 1.5, {}],
	["postel3", "postele", "furniture/bed_double_A", F, "lie", 1.55, 1.5, {}],
	["postel4", "postele", "furniture/bed_double_B", F, "lie", 1.55, 1.5, {}],
	["zidle1", "sezeni", "furniture/chair_A", F, "sit", 0.38, 0.43, {}],
	["zidle2", "sezeni", "furniture/chair_A_wood", F, "sit", 0.38, 0.43, {}],
	["zidle3", "sezeni", "furniture/chair_B", F, "sit", 0.38, 0.43, {}],
	["zidle4", "sezeni", "furniture/chair_B_wood", F, "sit", 0.38, 0.43, {}],
	["zidle5", "sezeni", "furniture/chair_C", F, "sit", 0.38, 0.47, {}],
	["stolicka1", "sezeni", "furniture/chair_stool", F, "sit", 0.38, 0.38, {}],
	["stolicka2", "sezeni", "furniture/chair_stool_wood", F, "sit", 0.38, 0.38, {}],
	["kreslo1", "sezeni", "furniture/armchair", F, "sit", 0.9, 0.8, {}],
	["kreslo2", "sezeni", "furniture/armchair_pillows", F, "sit", 0.9, 0.8, {}],
	["gauc1", "sezeni", "furniture/couch", F, "sit", 1.5, 0.8, {"seats": [-0.4, 0.4]}],
	["gauc2", "sezeni", "furniture/couch_pillows", F, "sit", 1.5, 0.8, {"seats": [-0.4, 0.4]}],
	["hernistul", "stoly", "", 1.0, "game", 0.5, 1.3, {}],
	["stul1", "stoly", "furniture/table_small", F, "read", 0.5, 0.5, {}],
	["stul2", "stoly", "furniture/table_medium", F, "read", 1.0, 1.0, {}],
	["stul3", "stoly", "furniture/table_medium_long", F, "read", 1.5, 1.0, {}],
	["stul4", "stoly", "furniture/table_low", F, "play", 1.2, 0.75, {}],
	["stul5", "stoly", "kitchen/table_round_A", K, "read", 1.26, 1.26, {}],
	["skrin1", "skrine", "furniture/cabinet_small", F, "hide", 0.5, 0.5, {}],
	["skrin2", "skrine", "furniture/cabinet_small_decorated", F, "hide", 0.5, 0.55, {}],
	["skrin3", "skrine", "furniture/cabinet_medium", F, "hide", 1.0, 0.5, {}],
	["skrin4", "skrine", "furniture/cabinet_medium_decorated", F, "hide", 1.0, 0.5, {}],
	["police1", "skrine", "furniture/shelf_A_small", F, "read", 0.5, 0.25, {"lift": 0.7}],
	["police2", "skrine", "furniture/shelf_A_big", F, "read", 1.0, 0.25, {"lift": 0.7}],
	["police3", "skrine", "furniture/shelf_B_small_decorated", F, "read", 0.5, 0.28, {"lift": 0.6}],
	["police4", "skrine", "furniture/shelf_B_large_decorated", F, "read", 1.0, 0.25, {"lift": 0.6}],
	["lampa1", "svetla", "furniture/lamp_standing", F, "lamp", 0.5, 0.5, {"light": 1.1}],
	["lampa2", "svetla", "furniture/lamp_table", F, "lamp", 0.5, 0.5, {"light": 0.45}],
	["koberec1", "koberce", "furniture/rug_oval_A", F, "dance", 1.5, 1.0, {"flat": true}],
	["koberec2", "koberce", "furniture/rug_oval_B", F, "dance", 1.5, 1.0, {"flat": true}],
	["koberec3", "koberce", "furniture/rug_rectangle_A", F, "dance", 1.5, 1.0, {"flat": true}],
	["koberec4", "koberce", "furniture/rug_rectangle_B", F, "dance", 1.5, 1.0, {"flat": true}],
	["koberec5", "koberce", "furniture/rug_rectangle_stripes_A", F, "dance", 1.5, 1.0, {"flat": true}],
	["koberec6", "koberce", "furniture/rug_rectangle_stripes_B", F, "dance", 1.5, 1.0, {"flat": true}],
	["kytka", "kytky", "", 1.0, "smell", 0.3, 0.3, {}],
	["kaktus1", "kytky", "furniture/cactus_small_A", F, "smell", 0.25, 0.25, {}],
	["kaktus2", "kytky", "furniture/cactus_small_B", F, "smell", 0.25, 0.25, {}],
	["kaktus3", "kytky", "furniture/cactus_medium_A", F, "smell", 0.44, 0.42, {}],
	["kaktus4", "kytky", "furniture/cactus_medium_B", F, "smell", 0.44, 0.42, {}],
	["obraz1", "dekorace", "furniture/pictureframe_large_A", F, "look", 0.5, 0.1, {"lift": 0.95}],
	["obraz2", "dekorace", "furniture/pictureframe_large_B", F, "look", 1.0, 0.1, {"lift": 0.95}],
	["obraz3", "dekorace", "furniture/pictureframe_medium", F, "look", 0.35, 0.1, {"lift": 0.95}],
	["obraz4", "dekorace", "furniture/pictureframe_small_A", F, "look", 0.25, 0.1, {"lift": 0.9}],
	["obraz5", "dekorace", "furniture/pictureframe_small_B", F, "look", 0.35, 0.1, {"lift": 0.9}],
	["obraz6", "dekorace", "furniture/pictureframe_small_C", F, "look", 0.25, 0.1, {"lift": 0.9}],
	["fotka1", "dekorace", "furniture/pictureframe_standing_A", F, "look", 0.25, 0.2, {}],
	["fotka2", "dekorace", "furniture/pictureframe_standing_B", F, "look", 0.35, 0.18, {}],
	["polstar1", "dekorace", "furniture/pillow_A", F, "hug", 0.33, 0.25, {"raise": 0.05}],
	["polstar2", "dekorace", "furniture/pillow_B", F, "hug", 0.33, 0.25, {"raise": 0.05}],
	["knihy1", "dekorace", "furniture/book_set", F, "read", 0.4, 0.18, {"raise": 0.125}],
	["knihy2", "dekorace", "furniture/book_single", F, "read", 0.13, 0.18, {"raise": 0.125}],
	["lednice", "kuchyn", "kitchen/fridge_A", K, "eat", 0.84, 0.94, {}],
	["trouba", "kuchyn", "kitchen/oven", K, "cook", 0.84, 0.99, {}],
	["linka", "kuchyn", "kitchen/kitchencounter_straight_A", K, "cook", 0.84, 0.86, {}],
	["drez", "kuchyn", "kitchen/kitchencounter_sink", K, "cook", 0.84, 0.86, {}],
	["burger", "kuchyn", "kitchen/food_burger", J, "eat", 0.24, 0.24, {}],
	["vecere", "kuchyn", "kitchen/food_dinner", J, "eat", 0.26, 0.24, {}],
	["talir", "kuchyn", "kitchen/plate", J, "eat", 0.24, 0.24, {}],
	["miska", "kuchyn", "kitchen/bowl", J, "eat", 0.24, 0.24, {}],
	["hrnec", "kuchyn", "kitchen/stew_pot", J * 1.4, "cook", 0.26, 0.26, {}],
	["sklenice", "kuchyn", "kitchen/jar_A_medium", J * 1.4, "eat", 0.18, 0.18, {}],
	["rajcata", "kuchyn", "kitchen/crate_tomatoes", J, "eat", 0.5, 0.5, {}],
	["mrkve", "kuchyn", "kitchen/crate_carrots", J, "eat", 0.5, 0.5, {}],
	["mic", "hracky", "", 1.0, "kick", 0.2, 0.2, {}],
	["medvidek", "hracky", "", 1.0, "hug", 0.25, 0.22, {}],
	["kostky", "hracky", "", 1.0, "play", 0.35, 0.35, {}],
	["autick", "hracky", "", 1.0, "play", 0.3, 0.2, {}],
	["akvarko", "zviratka", "", 1.0, "feed", 0.62, 0.36, {}],
	["kulate", "zviratka", "", 1.0, "feed", 0.34, 0.34, {}],
	["terarko", "zviratka", "", 1.0, "look", 0.62, 0.38, {"tip": "Mravenci staví cestičky a pomáhají si."}],
	["zelvicka", "zviratka", "", 1.0, "look", 0.66, 0.44, {"tip": "Želvička je pomalá, ale vytrvalá."}],
	["dort", "dobroty", "", 1.0, "eat", 0.4, 0.4, {"sweet": true}],
	["muffin", "dobroty", "", 1.0, "eat", 0.16, 0.16, {"sweet": true}],
	["koblih", "dobroty", "", 1.0, "eat", 0.18, 0.18, {"sweet": true}],
	["zmrzlina", "dobroty", "", 1.0, "eat", 0.12, 0.12, {"sweet": true}],
	["lizatko", "dobroty", "", 1.0, "eat", 0.16, 0.16, {"sweet": true}],
	["bonbony", "dobroty", "", 1.0, "eat", 0.28, 0.28, {"sweet": true}],
	["susenky", "dobroty", "", 1.0, "eat", 0.3, 0.3, {"sweet": true}],
	["palacinky", "dobroty", "", 1.0, "eat", 0.3, 0.3, {"sweet": true}],
	["jablko", "zdrave", "", 1.0, "eat", 0.14, 0.14, {"healthy": true}],
	["hruska", "zdrave", "", 1.0, "eat", 0.14, 0.14, {"healthy": true}],
	["banan", "zdrave", "", 1.0, "eat", 0.25, 0.2, {"healthy": true}],
	["pomeranc", "zdrave", "", 1.0, "eat", 0.15, 0.15, {"healthy": true}],
	["jahody", "zdrave", "", 1.0, "eat", 0.26, 0.26, {"healthy": true}],
	["hrozny", "zdrave", "", 1.0, "eat", 0.2, 0.2, {"healthy": true}],
	["meloun", "zdrave", "", 1.0, "eat", 0.28, 0.06, {"healthy": true}],
	["misaovoce", "zdrave", "", 1.0, "eat", 0.34, 0.34, {"healthy": true}],
	["brokolice", "zdrave", "", 1.0, "eat", 0.16, 0.16, {"healthy": true}],
	["okurka", "zdrave", "", 1.0, "eat", 0.22, 0.1, {"healthy": true}],
	["kukurice", "zdrave", "", 1.0, "eat", 0.24, 0.1, {"healthy": true}],
	["rajce", "zdrave", "kitchen/food_ingredient_tomato", 0.3, "eat", 0.15, 0.15, {"healthy": true}],
	["salat", "zdrave", "kitchen/food_ingredient_lettuce", 0.3, "eat", 0.2, 0.2, {"healthy": true}],
	["mrkev", "zdrave", "kitchen/food_ingredient_carrot", 0.3, "eat", 0.2, 0.1, {"healthy": true}],
	["brambora", "zdrave", "kitchen/food_ingredient_potato", 0.3, "eat", 0.15, 0.12, {"healthy": true}],
	["cibule", "zdrave", "kitchen/food_ingredient_onion", 0.3, "eat", 0.15, 0.15, {"healthy": true}],
	["syr", "zdrave", "kitchen/food_ingredient_cheese", 0.3, "eat", 0.2, 0.15, {"healthy": true}],
	["darek1", "darky", "", 1.0, "open", 0.26, 0.26, {}],
	["darek2", "darky", "", 1.0, "open", 0.2, 0.2, {}],
	["darek3", "darky", "", 1.0, "open", 0.32, 0.32, {}],
	["darek4", "darky", "", 1.0, "open", 0.22, 0.22, {}],
	["hvezdicka", "darky", "", 1.0, "wish", 0.2, 0.2, {"tip": "Hvězdička plní přání. Co si přeješ?"}],
	["hvezdy", "darky", "", 1.0, "wish", 0.36, 0.36, {"tip": "Pět hvězdiček za šikovnost!"}],
	["hvezdnalampa", "darky", "", 1.0, "lamp", 0.24, 0.24, {"light": 0.33}],
	["balonky", "darky", "", 1.0, "dance", 0.3, 0.3, {"tip": "Hurá, oslava!"}],
	["srdicko", "darky", "", 1.0, "hug", 0.25, 0.12, {"tip": "Obejmutí udělá radost."}],
	["kartacek", "pece", "", 1.0, "brush", 0.16, 0.12, {}],
	["umyvadlo", "pece", "", 1.0, "wash", 0.5, 0.36, {}],
	["mydlo", "pece", "", 1.0, "wash", 0.14, 0.1, {}],
	["rucnik", "pece", "", 1.0, "dry", 0.36, 0.16, {}],
	["hreben", "pece", "", 1.0, "comb", 0.16, 0.06, {}],
	["zachod", "pece", "", 1.0, "toilet", 0.3, 0.46, {}],
	["nocnik", "pece", "", 1.0, "toilet", 0.24, 0.24, {}],
	["vana", "pece", "", 1.0, "bath", 1.0, 0.55, {}],
	["voda", "pece", "", 1.0, "drink", 0.1, 0.1, {}],
	["kos", "pece", "", 1.0, "tidy", 0.24, 0.24, {}],
	["aktovka", "pece", "", 1.0, "read", 0.3, 0.14, {"tip": "Aktovku si sbalíme večer, ráno se nespěchá."}],
	["pastelky", "pece", "", 1.0, "draw", 0.34, 0.24, {"tip": "Nakresli, co tě dnes potěšilo."}],
	["budik", "pece", "", 1.0, "alarm", 0.14, 0.08, {"tip": "Dobré ráno! Nejdřív se protáhneme."}],
]

static var _all := {}

static func all() -> Dictionary:
	if _all.is_empty():
		for r in RAW:
			var e := {"id": r[0], "cat": r[1], "file": r[2], "scale": r[3], "act": r[4], "w": r[5], "d": r[6]}
			e.merge(r[7])
			_all[r[0]] = e
	return _all

static func get_item(id: String) -> Dictionary:
	return all().get(id, all()["kostky"])

static func in_cat(cat: String) -> Array:
	var out := []
	for r in RAW:
		if r[1] == cat: out.append(r[0])
	return out

## Krátký tip pro rodiče, co si u dané věci s dítětem říct.
const TIPS := {
	"brush": "Zoubky čistíme ráno a večer, aspoň 2 minutky.",
	"wash": "Ruce myjeme mýdlem před jídlem a po záchodě.",
	"dry": "Utřít ručičky do sucha.",
	"comb": "Učesat se a jsme krásní.",
	"toilet": "Hotovo? Spláchnout a umýt ruce!",
	"bath": "Koupání před spaním, pak pyžamo.",
	"drink": "Voda je nejlepší pití.",
	"tidy": "Odpadky patří do koše.",
	"lie": "Dobrou noc! Spánek dává sílu.",
	"feed": "Rybičky krmíme jen trošku, jednou denně.",
	"open": "Překvapení! Za dárek řekneme děkuji.",
}

static func tip(e: Dictionary) -> String:
	if e.has("tip"): return e["tip"]
	if e.get("healthy", false): return "Ovoce a zelenina dávají sílu a zdraví."
	if e.get("sweet", false): return "Sladkosti jen trošku a potom vyčistit zoubky."
	return TIPS.get(e["act"], "")

static func icon(id: String) -> Texture2D:
	var p := "res://icons/%s.png" % id
	return load(p) if ResourceLoader.exists(p) else null
