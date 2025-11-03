extends Control



func _on_client_pressed() -> void:
	Networking.start_client()


func _on_server_pressed() -> void:
	Networking.start_server()
