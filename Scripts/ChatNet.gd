# ChatNet.gd
extends Node

signal connected
signal disconnected
signal chat_message(from_name:String, text:String, avatar:ImageTexture)

const DEFAULT_PORT := 7777
const MAX_CLIENTS  := 16

var is_host := false
var my_name := ""
var my_avatar_img: Image # 64x64 Image from your UI

var room_id := ""
var room_name := ""
var current_players := 1


func host_room(port := DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err  = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("Failed to create server: %s" % err)
		return
	multiplayer.multiplayer_peer = peer
	is_host = true
	_multiplayer_ready()
	print("Hosting on port %d" % port)

func join_room(ip:String, port := DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err  = peer.create_client(ip, port)
	if err != OK:
		push_error("Failed to create client: %s" % err)
		return
	multiplayer.multiplayer_peer = peer
	is_host = false
	_multiplayer_ready()

func _multiplayer_ready() -> void:
	multiplayer.connection_failed.connect(func(): emit_signal("disconnected"))
	multiplayer.connected_to_server.connect(func():
		# on join: immediately send profile
		_send_profile_to_server()
		emit_signal("connected")
	)
	multiplayer.server_disconnected.connect(func(): emit_signal("disconnected"))

# ----- Simple profile exchange (username + avatar on join) -----

@rpc("any_peer","reliable")
func _rpc_receive_profile(peer_id:int, name:String, avatar_png:PackedByteArray) -> void:
	# Server receives from a new client; or clients receive from server (rebroadcast)
	if is_host:
		# keep a roster and rebroadcast to everyone (including new joiner)
		rpc("_rpc_broadcast_profile", peer_id, name, avatar_png)

@rpc("authority","reliable")
func _rpc_broadcast_profile(peer_id:int, name:String, avatar_png:PackedByteArray) -> void:
	# Everyone updates local roster
	var img := Image.new()
	if img.load_png_from_buffer(avatar_png) == OK:
		var tex := ImageTexture.create_from_image(img)
		# You’d store in a dictionary like {peer_id: {name, tex}}
		# For demo we just fire a “system message”
		emit_signal("chat_message", "[system]", "%s joined" % name, tex)

func _send_profile_to_server() -> void:
	# called by client on connect; server doesn’t call this
	if multiplayer.is_server():
		return
	var png := my_avatar_img.save_png_to_buffer()
	rpc_id(1, "_rpc_receive_profile", multiplayer.get_unique_id(), my_name, png)

# ----- Chat messages -----

@rpc("any_peer","reliable")
func _rpc_send_chat(name:String, text:String, avatar_png:PackedByteArray) -> void:
	# Server relays to everyone (authoritative echo)
	if is_host:
		rpc("_rpc_deliver_chat", name, text, avatar_png)

@rpc("authority","reliable")
func _rpc_deliver_chat(name:String, text:String, avatar_png:PackedByteArray) -> void:
	var img := Image.new()
	var tex:ImageTexture
	if img.load_png_from_buffer(avatar_png) == OK:
		tex = ImageTexture.create_from_image(img)
	emit_signal("chat_message", name, text, tex)

func send_chat(text:String) -> void:
	var png := my_avatar_img.save_png_to_buffer()
	if multiplayer.is_server():
		# host can send directly through the same pipeline
		_rpc_deliver_chat(my_name, text, png)
	else:
		rpc_id(1, "_rpc_send_chat", my_name, text, png)
		

func start_host_and_advertise(room_name_in:String, port := DEFAULT_PORT):
	room_name = room_name_in
	room_id = str(Time.get_unix_time_from_system()) + "-" + str(randi()) # quick unique id
	host_room(port)
	# timer to broadcast every second
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(func():
		var maxp = MAX_CLIENTS
		# If you track peers: current_players = 1 + multiplayer.get_peers().size()
		current_players = 1 + multiplayer.get_peers().size()
		$Discovery.advertise_room(room_id, room_name, port, current_players, maxp)
	)
	add_child(t)
