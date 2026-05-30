class_name UPNPManager
extends RefCounted

## Automatic UPnP port mapping for NAT traversal.
## Opens a port on the router so external players can connect.

var _upnp: UPNP = null
var _mapped_port: int = -1
var _public_ip: String = ""

## Try to open a port via UPnP. Returns true if successful.
func open_port(internal_port: int, description: String = "Godot Game") -> bool:
	_upnp = UPNP.new()
	
	var err = _upnp.discover()
	if err != OK:
		push_warning("UPNP: No UPnP device found (err=%d). LAN only." % err)
		return false
	
	var gateway = _upnp.get_gateway()
	if gateway == null or not gateway.is_valid_gateway():
		push_warning("UPNP: No valid gateway found.")
		return false
	
	_public_ip = _upnp.query_external_address()
	print("UPNP: Public IP = %s" % _public_ip)
	
	err = _upnp.add_port_mapping(internal_port, 0, description, "UDP")
	if err != OK:
		err = _upnp.add_port_mapping(internal_port, 0, description, "UDP")
	
	if err != OK:
		push_warning("UPNP: Failed to map port %d (err=%d)" % [internal_port, err])
		return false
	
	_mapped_port = internal_port
	print("UPNP: Port %d mapped successfully! External players can connect." % internal_port)
	return true

## Remove the port mapping
func close_port():
	if _upnp and _mapped_port > 0:
		_upnp.delete_port_mapping(_mapped_port, "UDP")
		print("UPNP: Port %d unmapped." % _mapped_port)
		_mapped_port = -1

## Get public IP for sharing with friends
func get_public_ip() -> String:
	return _public_ip

## Is UPnP active?
func is_active() -> bool:
	return _mapped_port > 0
