class_name Data
## Barvy, volby a ukládání.

const INK := Color("4a3a6a")
const PINK := Color("ff8ab3")
const MINT := Color("5cc6b8")
const LILAC := Color("e4dbff")
const BG := Color("f4eeff")

const SKIN := [Color("ffdcc2"), Color("eab894"), Color("b98058"), Color("7d5236"), Color("a9dcb0"), Color("b4ccff"), Color("ffc2db"), Color("9bc48a"), Color("b9a2e6"), Color("f2f0e6"), Color("ff7a6e"), Color("8a98a8"), Color("f8f8ff")]
const YARN := [Color("ff8ab3"), Color("5cc6b8"), Color("ffc93c"), Color("9b7cff"), Color("6fa8ff"), Color("ff7a59"), Color("f6f2ff"), Color("4a3a6a")]
const HAIRC := [Color("4a3020"), Color("9a6634"), Color("f2c14e"), Color("d8532c"), Color("7b5be0"), Color("2a2230"), Color("ff9ec4")]
const WALL := [Color("ffe8c2"), Color("d6f0ff"), Color("e8ddff"), Color("d9f5d0"), Color("ffd6e0"), Color("fff6a8"), Color("ffffff"), Color("c9e9ff")]
const FLOOR := [Color("c98b55"), Color("e7c9a0"), Color("a7b1bb"), Color("8fc79a"), Color("b99ae0"), Color("ff9ec4"), Color("8fc4ff"), Color("f6f2ff")]
const WALLP := ["hladká", "proužky", "puntíky", "hvězdičky", "vlastní"]
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
	"hat": ["nic", "kulich", "mašle"],
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
