extends Control

@onready var room_list  : ItemList       = $RoomList
@onready var room_name  : LineEdit       = $RoomInfo/RoomName
@onready var port_spin  : SpinBox        = $RoomInfo/Port
@onready var create_btn : Button         = $Buttons/CreateBtn
@onready var join_btn   : Button         = $Buttons/JoinBtn
@onready var refresh_btn: Button         = $Buttons/RefreshBtn
@onready var status_lbl : Label          = $Status
@onready var adv_timer  : Timer          = $AdvTimer

const MAX_PLAYERS := 16

# room_id -> { name, ip, port, players, max }
var rooms: Dictionary = {}
# item index -> room_id
var index_to_id: Dictionary = {}

# host-side state for advertising
var hosting := false
var hosted_room_id := ""
var hosted_room_name := ""

func _ready() -> void:
	# UI
	room_list.item_activated.connect(_on_room_activated)
	create_btn.pressed.connect(_create_room)
	join_btn.pressed.connect(_join_selected)
	refresh_btn.pressed.connect(_refresh_rooms)

	# Discovery signals (autoload)
	Discovery.room_found.connect(_on_room_found)
	Discovery.room_lost.connect(_on_room_lost)

	# ChatNet signals (autoload)
	ChatNet.connected.connect(_on_connected)
	ChatNet.disconnected.connect(_on_disconnected)

	# Timer to periodically advertise while hosting
	adv_timer.timeout.connect(_advertise_tick)

	status_lbl.text = "Not connected. Browse or create."
	# sane defaults
	if port_spin.value <= 0:
		port_spin.value = 7777

func _on_room_found(room_id:String, name:String, ip:String, port:int, players:int, max_players:int) -> void:
	rooms[room_id] = {
		"name": name, "ip": ip, "port": port,
		"players": players, "max": max_players
	}
	_rebuild_list()

func _on_room_lost(room_id:String) -> void:
	rooms.erase(room_id)
	_rebuild_list()

func _rebuild_list() -> void:
	room_list.clear()
	index_to_id.clear()
	var idx := 0
	for id in rooms.keys():
		var r = rooms[id]
		var line = "%s  —  %s:%d  (%d/%d)" % [r.name, r.ip, r.port, r.players, r.max]
		room_list.add_item(line)
		index_to_id[idx] = id
		idx += 1

func _refresh_rooms() -> void:
	# Just wipe and let Discovery repopulate on next packets
	rooms.clear()
	_rebuild_list()
	status_lbl.text = "Refreshing… waiting for broadcasts."

func _create_room() -> void:
	if hosting:
		status_lbl.text = "Already hosting."
		return

	var name := room_name.text.strip_edges()
	if name.is_empty():
		status_lbl.text = "Enter a room name."
		return

	var port := int(port_spin.value)

	# Spin up ENet server
	ChatNet.host_room(port)
	if ChatNet.multiplayer.multiplayer_peer == null:
		status_lbl.text = "Failed to host (no peer)."
		return

	# mark host state & start advertising
	hosting = true
	hosted_room_name = name
	hosted_room_id = "%s-%d" % [str(Time.get_unix_time_from_system()), randi()]
	adv_timer.wait_time = 1.0
	adv_timer.start()

	status_lbl.text = "Hosting '%s' on :%d — advertising on LAN…" % [name, port]

func _advertise_tick() -> void:
	# if not hosting anymore, stop
	if not hosting or ChatNet.multiplayer.multiplayer_peer == null:
		adv_timer.stop()
		return

	var port := int(port_spin.value)
	var players := 1 + ChatNet.multiplayer.get_peers().size()
	Discovery.advertise_room(hosted_room_id, hosted_room_name, port, players, MAX_PLAYERS)

func _join_selected() -> void:
	var sel := room_list.get_selected_items()
	if sel.is_empty():
		status_lbl.text = "Select a room first."
		return

	var idx := sel[0]
	var room_id: String = str(index_to_id.get(idx, ""))
	
	if room_id == "":
		status_lbl.text = "Invalid selection."
		return

	var r = rooms[room_id]
	status_lbl.text = "Joining %s (%s:%d)…" % [r.name, r.ip, r.port]
	ChatNet.join_room(r.ip, int(r.port))

func _on_room_activated(index:int) -> void:
	# double-click to join
	room_list.select(index)
	_join_selected()

func _on_connected() -> void:
	status_lbl.text = "Connected. Loading chat…"
	# If you have a chat scene, change here:
	# get_tree().change_scene_to_file("res://Chat.tscn")
	# Otherwise, stay and let Chat UI live elsewhere.

func _on_disconnected() -> void:
	status_lbl.text = "Disconnected."
	# If we were hosting, stop advertising
	if hosting:
		hosting = false
		adv_timer.stop()
