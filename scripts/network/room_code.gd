class_name RoomCode
extends RefCounted

## Encodes IP:port into a short room code, and decodes it back.
## Format: 5-8 char alphanumeric string.

const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # No 0/O/I/1 to avoid confusion

## Encode "ip:port" → room code (e.g., "X7K2NP")
static func encode(ip: String, port: int) -> String:
	var parts = ip.split(".")
	if parts.size() != 4:
		return ""
	
	# Pack IP (4 bytes) + port (2 bytes) into a buffer
	var buf := PackedByteArray()
	for p in parts:
		buf.append(int(p) & 0xFF)
	buf.append((port >> 8) & 0xFF)
	buf.append(port & 0xFF)
	
	# Convert to base-N string
	return _bytes_to_code(buf)

## Decode room code → {"ip": "x.x.x.x", "port": N} or empty dict
static func decode(code: String) -> Dictionary:
	var buf := _code_to_bytes(code)
	if buf.size() < 6:
		return {}
	
	var ip := "%d.%d.%d.%d" % [buf[0], buf[1], buf[2], buf[3]]
	var port := (buf[4] << 8) | buf[5]
	
	if port < 1 or port > 65535:
		return {}
	
	return {"ip": ip, "port": port}

## Generate a random suffix to make codes unique even with same IP
static func generate_suffix(length: int = 2) -> String:
	var result := ""
	for i in range(length):
		result += CHARS[randi() % CHARS.length()]
	return result

static func _bytes_to_code(data: PackedByteArray) -> String:
	# Simple base-N encoding
	var value := 0
	for b in data:
		value = (value << 8) | b
	
	var result := ""
	while value > 0:
		result = CHARS[value % CHARS.length()] + result
		value /= CHARS.length()
	
	return result if result != "" else "A"

static func _code_to_bytes(code: String) -> PackedByteArray:
	var value := 0
	for c in code.to_upper():
		var idx = CHARS.find(c)
		if idx < 0:
			continue  # Skip invalid chars
		value = value * CHARS.length() + idx
	
	var buf := PackedByteArray()
	while value > 0:
		buf.insert(0, value & 0xFF)
		value >>= 8
	
	# Pad to 6 bytes
	while buf.size() < 6:
		buf.insert(0, 0)
	
	return buf
