class_name NetworkConnectionConfigs
extends Resource

@export var host_ip: String = ""
@export var host_port: int = -1
@export var game_id: String = ""
@export var steam_host_id: int = 0  ## Steam ID of the host player

func _init(host_ip_: String = ""):
	host_ip = host_ip_

## Creates config for Steam-based connections
static func for_steam(host_steam_id: int) -> NetworkConnectionConfigs:
	var config = NetworkConnectionConfigs.new()
	config.steam_host_id = host_steam_id
	return config
