# Můj Pokojíček 3D – základ hry v Godotu (Android)

## Spuštění
1. Stáhněte Godot 4.3 nebo novější (zdarma): https://godotengine.org/download
2. Godot → Import → vyberte `project.godot` → ▶. Myš funguje jako prst.

## Jak se hraje
- **Panenka:** postava, tvar hlavy, 13 barev (i zombie, duch, čertík), 12 druhů očí,
  obočí, nos, pusa (i upír, zubatá, sešitá), pihy, brýle, stehy, mumie, pirát, knír,
  8 druhů uší, 8 účesů, růžky / jednorožec / tykadla / šroubky, ocásky, křídla,
  oblečení a čepice. Tlačítko „Náhodná postavička“ vymyslí novou.
- **Pokojíček → Hrát:** ťukni na věc a panenka k ní dojde a něco s ní udělá:
  | Věc | Co panenka udělá |
  | --- | --- |
  | růžový herní stůl | sedne si na stoličku, dva u stolu = pexeso |
  | židle, křesla, gauč | sedne si |
| lednice, jídlo | jí |
| trouba, linka | vaří |
| police, knihy, stoly | čte si |
| obrázky | ukazuje na ně |
| kostky, autíčko | hraje si na zemi |
  | postel | lehne si |
  | koberec | tancuje |
  | míč | kopne do něj a míč odletí |
  | lampa | rozsvítí nebo zhasne |
  | kytka | přičichne |
  | medvídek | obejme ho |
  | skříň | schová se do ní |
  Ťuknutí na podlahu = panenka tam dojde.
- **Pokojíček → Zařizovat:** 121 věcí v 15 druzích (postele, sezení, stoly, skříně a police,
  světla, koberce, kytky, obrázky a polštáře, kuchyňka, hračky, zvířátka, dobroty,
  ovoce a zelenina, dárky a hvězdičky, péče a návyky), vybírá se podle obrázků.
- **Živé věci:** rybičky plavou, mravenci chodí po cestičkách, želvička se prochází,
  hvězdičky se točí, balónky se kývají, svíčky na dortu plápolají.
- **Učení návyků:** u kartáčku si panenka čistí zuby, u umyvadla myje ruce, na záchodě
  a nočníku sedí, ve vaně se koupe, u koše uklízí… Nahoře se ukáže krátký tip pro rodiče
  („Zoubky čistíme ráno a večer, aspoň 2 minutky.“, „Ovoce a zelenina dávají sílu.“…).
- **Chůze:** panenka obchází nábytek. Do malých věcí strčí: míček se odkutálí,
  kostičky se rozsypou (když si s nimi pak hraje, zase je postaví), skleničky se převrhnou.
  Stěny: 8 barev × 4 vzory, podlahy: 8 barev × 4 vzory. Obrázky a police se samy přilepí na zeď.
- **Okno:** ťukni na okno, panenka k němu dojde a kamera ukáže ulici. Počasí: slunce, déšť,
  sníh (tráva zbělá), vítr (stromy se kývají, létá listí), noc s hvězdami, duha.
- **Pexeso:** když dvě panenky sedí u jednoho stolu, oběma dětem se na telefonu otevře stejné
  pexeso a hrají proti sobě. Kdo sedí u stolu sám a bez kamarádů, hraje s počítačem.

## Kamarádi (bez serveru, stejná WiFi)
Jeden „Pozve kamarády k sobě“, ostatní „Hledají kamarády“ a ťuknou na jméno.
Každý ovládá svou panenku ťukáním, ostatní vidí, kam jde a co dělá.
Hostitelův telefon řídí pexeso (míchá karty, hlídá tahy).

Zkouška na jednom počítači: Debug → Customize Run Instances → 2 instance; v druhém okně
lze zadat adresu 127.0.0.1 a „Jít“.

## Soubory
- `doll.gd` – vzhled panenky a animace (chůze, sezení, ležení, tanec…)
- `room.gd` – pokoj a nábytek
- `interact.gd` – kam panenka u které věci dojde a co udělá
- `paths.gd` – hledání cesty kolem nábytku
- `props.gd` – zvířátka, dobroty, ovoce, dárky, péče (poskládané v kódu)
- `catalog.gd` – seznam všech věcí, jejich akce a tipy pro rodiče
- `pexeso.gd` – pravidla pexesa, `card.gd` – kartička
- `net.gd` – WiFi spojení a posílání pohybů a tahů
- `main.gd` – obrazovky a ovládání
- `yarn.gd` – materiál a pomocné tvary, `data.gd` – volby a ukládání

## Export do Androidu
1. Editor → Manage Export Templates → Download and Install.
2. Android SDK a JDK 17 podle https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
3. Project → Export → Add… → Android, v Permissions zaškrtněte Internet, Access Network State,
   Access Wifi State, Change Wifi Multicast State → Export Project.

## Modely (zdarma, CC0)
Nábytek, kuchyňka a ulice jsou z balíčků KayKit od Kay Lousberg (www.kaylousberg.com):
Furniture Bits, Restaurant Bits a City Builder Bits. Licence CC0: můžete je používat
i v placené hře, uvedení autora není povinné (ale je hezké). Licence leží u modelů
v `models/*/LICENSE.txt`. Další se dají přidat do `catalog.gd` (jeden řádek na věc)
a obrázky tlačítek jsou v `icons/`.
