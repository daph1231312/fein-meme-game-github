# Discovery.gd
extends Node

signal room_found(room_id:String, name:String, ip:String, port:int, players:int, max_players:int)
signal room_lost(room_id:String)

const DISCOVERY_PORT := 8999
const TICK_MS := 1000

var udp := PacketPeerUDP.new()
var rooms := {} # room_id -> {name, ip, port, players, max_players, last_seen_ms}

func _ready() -> void:
	udp.set_broadcast_enabled(true)
	var ok = udp.bind(DISCOVERY_PORT, "*")
	if ok != OK:
		push_error("Discovery bind failed: %s" % ok)
		return
	set_process(true)

func _process(delta:float) -> void:
	# receive
	while udp.get_available_packet_count() > 0:
		var bytes := udp.get_packet()
		var txt := bytes.get_string_from_utf8()
		var parts := txt.split(";")
		if parts.size() >= 6 and parts[0] == "ROOM":
			var id = parts[1]
			var data = {
				"name": parts[2],
				"ip": udp.get_packet_ip(),
				"port": int(parts[3]),
				"players": int(parts[4]),
				"max": int(parts[5]),
				"last_seen": Time.get_ticks_msec()
			}
			var first_time = not rooms.has(id)
			rooms[id] = data
			if first_time:
				emit_signal("room_found", id, data.name, data.ip, data.port, data.players, data.max)
	# prune stale rooms (3s timeout)
	var now = Time.get_ticks_msec()
	for id in rooms.keys():
		if now - rooms[id].last_seen > 3000:
			rooms.erase(id)
			emit_signal("room_lost", id)

# Host call this periodically:
func advertise_room(room_id:String, name:String, port:int, players:int, max_players:int) -> void:
	var pkt = "ROOM;%s;%s;%d;%d;%d" % [room_id, name, port, players, max_players]
	udp.connect_to_host("255.255.255.255", DISCOVERY_PORT)
	udp.put_packet(pkt.to_utf8_buffer())
