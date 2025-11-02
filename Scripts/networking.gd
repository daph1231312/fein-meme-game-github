extends Node

const ipAddr: String = "localhost"
const port: int = 42069

var peer: ENetMultiplayerPeer

func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_server(port)
	multiplayer.multiplayer_peer = peer

func start_client() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ipAddr, port)
	multiplayer.multiplayer_peer = peer
