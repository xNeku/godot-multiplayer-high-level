extends Control

func _on_server_pressed() -> void:
	HighLevelNetworkHandler.start_server()


func _on_client_pressed() -> void:
	HighLevelNetworkHandler.start_client()


func _on_host_pressed() -> void:
	HighLevelNetworkHandler.start_host()
