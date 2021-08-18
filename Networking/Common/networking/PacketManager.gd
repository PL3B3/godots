extends Reference

class_name PacketManager

"""
	The first place a packet goes after received, and the place an instruction
	goes to be serialized and sent. 
	Upon receiving a packet, deserializes it and uses the packet information to 
	decide which SyncHandler to pass it to 
"""

var sz:PacketSerializer

func _init():
	sz = PacketSerializer.new()

func _on_connect():
	pass
