extends Node
## Propojení přes domácí WiFi, bez serveru.
## Hostitel "otevře pokojíček": čeká na ENet portu 4242 a každou sekundu
## hlásí do sítě (UDP broadcast, port 4243), že je k dispozici.
## Hostitel je vždy "pravda": přeposílá pohyby panenek a řídí pexeso.

signal found(name: String, ip: String)
signal joined(id: int, data: Dictionary)          # u hostitele: přišel kamarád
signal left(id: int)                              # u hostitele: kamarád odešel
signal welcome(roster: Dictionary, room: Dictionary)  # u hosta: jsem uvnitř
signal roster(roster: Dictionary)                 # u hosta: změna seznamu
signal cmd(id: int, c: Dictionary)                # někdo se pohnul
signal flip(id: int, i: int)                      # u hostitele: někdo otočil kartu
signal game(state: Dictionary)                    # u hosta: stav pexesa
signal lost
signal status(text: String)

const PORT := 4242
const DISCOVERY_PORT := 4243

var my_data: Dictionary = {}
var hosting := false
var is_client := false
var _listen := PacketPeerUDP.new()
var _shout := PacketPeerUDP.new()
var _t := 0.0

func _ready() -> void:
	multiplayer.peer_disconnected.connect(func(id): if hosting: left.emit(id))
	multiplayer.connected_to_server.connect(func(): c_hello.rpc_id(1, my_data))
	multiplayer.connection_failed.connect(func(): is_client = false; status.emit("Nepodařilo se připojit. Jste na stejné WiFi?"))
	multiplayer.server_disconnected.connect(func(): is_client = false; status.emit("Kamarád zavřel pokojíček."); lost.emit())

static func my_ip() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
	return "?"

func connected() -> bool:
	return hosting or is_client

func my_id() -> int:
	return multiplayer.get_unique_id() if is_client else 1

func open_room(data: Dictionary) -> void:
	stop()
	my_data = data
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, 6) != OK:
		status.emit("Pokojíček nejde otevřít.")
		return
	multiplayer.multiplayer_peer = peer
	_shout.set_broadcast_enabled(true)
	_shout.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	hosting = true
	status.emit("Pokojíček je otevřený. Kamarádi tě teď najdou.")

func search() -> void:
	stop()
	if _listen.bind(DISCOVERY_PORT) != OK: status.emit("Hledání nejde spustit.")
	else: status.emit("Hledám kamarády na WiFi…")

func visit(ip: String, data: Dictionary) -> void:
	stop()
	my_data = data
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, PORT) != OK:
		status.emit("Adresa nesedí.")
		return
	multiplayer.multiplayer_peer = peer
	is_client = true
	status.emit("Jdu na návštěvu…")

func stop() -> void:
	hosting = false
	is_client = false
	_listen.close()
	_shout.close()
	if not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func _process(delta: float) -> void:
	if hosting:
		_t += delta
		if _t > 1.0:
			_t = 0.0
			_shout.put_packet(JSON.stringify({"game": "pokojicek", "name": my_data.get("name", "")}).to_utf8_buffer())
	if _listen.is_bound():
		while _listen.get_available_packet_count() > 0:
			var msg = JSON.parse_string(_listen.get_packet().get_string_from_utf8())
			var ip := _listen.get_packet_ip()
			if msg is Dictionary and msg.get("game") == "pokojicek":
				found.emit(str(msg.get("name", "?")), ip)

# ---- příchod ----
@rpc("any_peer", "reliable")
func c_hello(d: Dictionary) -> void:
	if hosting and Data.is_valid(d):
		joined.emit(multiplayer.get_remote_sender_id(), d)

func send_welcome(id: int, r: Dictionary, room: Dictionary) -> void:
	s_welcome.rpc_id(id, r, room)

@rpc("authority", "reliable")
func s_welcome(r: Dictionary, room: Dictionary) -> void:
	status.emit("Jsi na návštěvě.")
	welcome.emit(r, room)

func send_roster(r: Dictionary) -> void:
	if hosting: s_roster.rpc(r)

@rpc("authority", "reliable")
func s_roster(r: Dictionary) -> void:
	roster.emit(r)

# ---- pohyb panenek ----
func send_cmd(c: Dictionary) -> void:
	if is_client: c_cmd.rpc_id(1, c)
	elif hosting: s_cmd.rpc(1, c)

@rpc("any_peer", "reliable")
func c_cmd(c: Dictionary) -> void:
	if not hosting: return
	var id := multiplayer.get_remote_sender_id()
	cmd.emit(id, c)
	s_cmd.rpc(id, c)

@rpc("authority", "reliable")
func s_cmd(id: int, c: Dictionary) -> void:
	cmd.emit(id, c)

# ---- pexeso ----
func send_flip(i: int) -> void:
	if is_client: c_flip.rpc_id(1, i)

@rpc("any_peer", "reliable")
func c_flip(i: int) -> void:
	if hosting: flip.emit(multiplayer.get_remote_sender_id(), i)

func send_game(st: Dictionary) -> void:
	if hosting: s_game.rpc(st)

@rpc("authority", "reliable")
func s_game(st: Dictionary) -> void:
	game.emit(st)
