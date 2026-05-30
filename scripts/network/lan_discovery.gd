class_name LANDiscovery
extends RefCounted

## UDP LAN broadcast discovery.
## Host broadcasts its presence. Clients listen and find available games.

const BROADCAST_PORT := 8081
const MAGIC := "GODOT3DMP".to_ascii_buffer()

var _udp: PacketPeerUDP = null
var _broadcast_timer: float = 0.0

## Start broadcasting as host
func start_broadcast(server_port: int):
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	_udp.set_dest_address("255.255.255.255", BROADCAST_PORT)
	print("LAN: Broadcasting game on port %d" % server_port)
	
	# Encode port in the broadcast message
	var msg := MAGIC.duplicate()
	msg.append((server_port >> 8) & 0xFF)
	msg.append(server_port & 0xFF)
	_udp.put_packet(msg)

## Start listening for broadcasts (client)
func start_listening() -> PacketPeerUDP:
	_udp = PacketPeerUDP.new()
	_udp.bind(BROADCAST_PORT)
	print("LAN: Listening for games...")
	return _udp

## Check for incoming broadcasts, returns {"ip": str, "port": int} or empty
func check_for_game(udp: PacketPeerUDP) -> Dictionary:
	if not udp or udp.get_available_packet_count() == 0:
		return {}
	
	var packet = udp.get_packet()
	if packet.size() < MAGIC.size() + 2:
		return {}
	
	# Verify magic
	for i in range(MAGIC.size()):
		if packet[i] != MAGIC[i]:
			return {}
	
	var port := (packet[MAGIC.size()] << 8) | packet[MAGIC.size() + 1]
	var ip := udp.get_packet_ip()
	
	print("LAN: Found game at %s:%d" % [ip, port])
	return {"ip": ip, "port": port}

## Clean up
func stop():
	if _udp:
		_udp.close()
		_udp = null
