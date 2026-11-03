class_name Data
## Barvy, volby a ukládání.

const INK := Color("4a3a6a")
static var PINK := Color("ff8ab3")      # zvýraznění (vybraná tlačítka)
const MINT := Color("5cc6b8")
static var LILAC := Color("e4dbff")     # okraje panelů
static var BG := Color("f4eeff")        # pozadí aplikace
static var STAGE := Color("ffe9f3")     # pozadí scény
static var theme := "girl"

## Holčičí (růžovofialový) nebo klučičí (modrooranžový) vzhled.
static func apply_theme(t: String) -> void:
	theme = t
	if t == "boy":
		PINK = Color("ff9f1c"); LILAC = Color("cfe3ff"); BG = Color("e9f3ff"); STAGE = Color("e3f0ff")
	else:
		PINK = Color("ff8ab3"); LILAC = Color("e4dbff"); BG = Color("f4eeff"); STAGE = Color("ffe9f3")

## Hotoví kamarádi: z nich si dítě vybere a pak jen doladí.
const PRESETS := [
	{"hair": 2, "hairc": 3, "eyes": 1, "brows": 1, "nose": 0, "mouth": 0, "ears": 5, "top": 2, "topc": 0, "bottom": 1, "botc": 6, "hat": 2, "hatc": 3, "skin": 0, "extra": 0, "figure": 1, "shoes": 0},
	{"hair": 4, "hairc": 2, "eyes": 1, "brows": 1, "nose": 0, "mouth": 1, "ears": 5, "top": 1, "topc": 3, "bottom": 1, "botc": 6, "hat": 0, "skin": 0, "extra": 1, "figure": 1, "shoes": 3},
	{"hair": 5, "hairc": 0, "eyes": 1, "brows": 1, "nose": 0, "mouth": 7, "ears": 5, "top": 0, "topc": 1, "bottom": 0, "botc": 4, "hat": 0, "skin": 2, "extra": 0, "figure": 1, "shoes": 7},
	{"hair": 1, "hairc": 1, "eyes": 1, "brows": 1, "nose": 0, "mouth": 0, "ears": 5, "top": 0, "topc": 4, "bottom": 2, "botc": 7, "hat": 3, "hatc": 5, "skin": 1, "extra": 0, "figure": 1, "shoes": 5},
	{"hair": 7, "hairc": 5, "eyes": 1, "brows": 1, "nose": 0, "mouth": 1, "ears": 5, "top": 1, "topc": 1, "bottom": 0, "botc": 7, "hat": 0, "skin": 3, "extra": 2, "figure": 1, "shoes": 4},
	{"hair": 6, "hairc": 2, "eyes": 1, "brows": 1, "nose": 0, "mouth": 0, "ears": 5, "top": 0, "topc": 5, "bottom": 0, "botc": 4, "hat": 4, "hatc": 2, "skin": 0, "extra": 1, "figure": 0, "shoes": 7},
	{"hair": 0, "eyes": 1, "brows": 0, "nose": 7, "mouth": 0, "ears": 1, "tail": 2, "skin": 6, "top": 2, "topc": 6, "bottom": 1, "botc": 0, "hat": 2, "hatc": 0, "extra": 0, "figure": 0, "shoes": 0},
	{"hair": 0, "eyes": 1, "brows": 0, "nose": 1, "mouth": 7, "ears": 5, "horns": 1, "tail": 4, "skin": 7, "top": 0, "topc": 2, "bottom": 2, "botc": 4, "hat": 0, "extra": 0, "figure": 3, "shoes": 2},
	{"hair": 0, "eyes": 0, "brows": 0, "nose": 8, "mouth": 0, "ears": 0, "tail": 3, "skin": 2, "top": 1, "topc": 5, "bottom": 0, "botc": 4, "hat": 0, "extra": 0, "figure": 3, "shoes": 7},
	{"hair": 0, "eyes": 1, "brows": 0, "nose": 10, "mouth": 7, "ears": 2, "skin": 9, "top": 0, "topc": 0, "bottom": 2, "botc": 3, "hat": 0, "extra": 0, "figure": 0, "shoes": 0},
	{"style": "kk", "kkhead": 0, "kkhat": 1, "kkbody": 0, "kkarms": 0, "kklegs": 0, "kkcape": 1},
	{"style": "kk", "kkhead": 1, "kkhat": 2, "kkbody": 1, "kkarms": 1, "kklegs": 1, "kkcape": 2},
	{"style": "kk", "kkhead": 2, "kkhat": 3, "kkbody": 2, "kkarms": 2, "kklegs": 2, "kkcape": 3},
	{"style": "kk", "kkhead": 4, "kkhat": 0, "kkbody": 4, "kkarms": 4, "kklegs": 4, "kkcape": 4},
	{"style": "kk", "kkhead": 5, "kkhat": 0, "kkbody": 5, "kkarms": 5, "kklegs": 5, "kkcape": 5},
	{"style": "kk", "kkhead": 8, "kkhat": 6, "kkbody": 8, "kkarms": 8, "kklegs": 8, "kkcape": 7},
]
const GIRL_ORDER := [0, 1, 2, 6, 9, 11, 3, 4, 5, 7, 8, 10, 12, 13, 14, 15]
const BOY_ORDER := [3, 4, 5, 10, 7, 12, 15, 13, 14, 8, 0, 1, 2, 6, 9, 11]

const SKIN := [Color("ffdcc2"), Color("eab894"), Color("b98058"), Color("7d5236"), Color("a9dcb0"), Color("b4ccff"), Color("ffc2db"), Color("9bc48a"), Color("b9a2e6"), Color("f2f0e6"), Color("ff7a6e"), Color("8a98a8"), Color("f8f8ff")]
const YARN := [Color("ff8ab3"), Color("5cc6b8"), Color("ffc93c"), Color("9b7cff"), Color("6fa8ff"), Color("ff7a59"), Color("f6f2ff"), Color("4a3a6a")]
const HAIRC := [Color("4a3020"), Color("9a6634"), Color("f2c14e"), Color("d8532c"), Color("7b5be0"), Color("2a2230"), Color("ff9ec4")]
const WALL := [Color("ffe8c2"), Color("d6f0ff"), Color("e8ddff"), Color("d9f5d0"), Color("ffd6e0"), Color("fff6a8"), Color("ffffff"), Color("c9e9ff")]
const FLOOR := [Color("c98b55"), Color("e7c9a0"), Color("a7b1bb"), Color("8fc79a"), Color("b99ae0"), Color("ff9ec4"), Color("8fc4ff"), Color("f6f2ff")]
const WALLP := ["hladká", "proužky", "puntíky", "hvězdičky", "vlastní", "příroda", "zámek", "jeskyně", "dinosauři", "vesmír", "moře", "louka"]
const MURALS := ["priroda", "zamek", "jeskyne", "dinosauri", "vesmir", "more", "louka"]
const FLOORP := ["hladká", "prkna", "dlaždice", "šachovnice"]
const WEATHER := ["slunce", "dest", "snih", "vitr", "noc", "duha"]

const OPT := {
	"figure": ["malá", "střední", "vysoká", "baculatá"],
	"headshape": ["kulatá", "fazolka", "kapka", "dlouhá", "trojlístek", "kostička", "hruška", "srdíčko"],
	"headw": ["1", "2", "3", "4", "5"],
	"headh": ["1", "2", "3", "4", "5"],
	"headd": ["1", "2", "3"],
	"eyes": ["tečky", "velké", "ospalé", "mrkající", "kyklop", "tři oči", "křížky", "knoflíky", "srdíčka", "svítící", "každé jiné", "spirály"],
	"brows": ["žádné", "obyčejné", "zamračené", "překvapené", "srostlé"],
	"nose": ["knoflík", "kulatý", "rypáček", "lebka", "čumáček", "žádný", "pejsek", "kočička", "medvídek", "zobáček", "myška"],
	"mouth": ["úsměv", "smích", "Ó", "upír", "zubatá", "sešitá", "jazyk", "zoubky"],
	"ears": ["medvěd", "kočka", "zajíc", "pejsek", "myška", "žádné", "elf", "netopýr"],
	"horns": ["nic", "růžky", "jednorožec", "tykadla", "šroubky", "býčí"],
	"tail": ["nic", "čertík", "kočička", "medvídek", "dráček"],
	"wings": ["nic", "netopýr", "motýlek", "andílek"],
	"hair": ["žádné", "krátké", "copánky", "kudrny", "dlouhé", "culík", "mikádo", "ježek"],
	"extra": ["nic", "pihy", "brýle", "brýle a pihy", "stehy", "náplast", "mumie", "pirát", "knír"],
	"top": ["tričko", "svetr", "šaty"],
	"bottom": ["kalhoty", "sukně", "kraťasy"],
	"hat": ["nic", "kulich", "mašle", "kšiltovka", "korunka"],
}
const SAVE_PATH := "user://pokojicek_v2.json"

static func default_state() -> Dictionary:
	return {
		"name": "Já",
		"hero": {"figure": 1, "headshape": 0, "headw": 2, "headh": 2, "headd": 1, "extra": 0, "skin": 0, "eyes": 1, "ears": 0, "hair": 2, "hairc": 1, "top": 1, "topc": 0,
			"bottom": 1, "botc": 4, "shoes": 7, "hat": 0, "hatc": 2},
		"weather": 0,
		"room": {"wall": 1, "wallp": 2, "floor": 0, "floorp": 1, "items": [["postel1", -1.85, -1.1, 0], ["koberec2", 0.0, 0.4, 0], ["lampa1", -2.15, 0.2, 0], ["kaktus3", 2.1, -1.65, 0], ["medvidek", 1.3, 0.9, 0], ["hernistul", 1.15, -0.6, 90], ["mic", -0.6, 1.2, 0], ["skrin4", -0.6, -1.7, 0], ["obraz2", 1.5, -1.95, 0], ["kreslo2", 2.0, 1.1, 270], ["kostky", 0.6, 1.4, 0]]},
	}

static func load_state() -> Dictionary:
	if FileAccess.file_exists(SAVE_PATH):
		var d = JSON.parse_string(FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text())
		if is_valid(d):
			return d
	return default_state()

static func save_state(s: Dictionary) -> void:
	FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_string(JSON.stringify(s))

## Kontrola dat od kamaráda, aby hra nespadla.
static func is_valid(d) -> bool:
	return d is Dictionary and d.has("name") and d.get("hero") is Dictionary and d.get("room") is Dictionary and d["room"].get("items") is Array

static func pick(list: Array, i) -> Variant:
	return list[clampi(int(i), 0, list.size() - 1)]
