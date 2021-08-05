extends Node

class_name RingBuffer

# constant-size byte ringbuffer holding serialized snapshots / instructions
# snapshots 

const ID_MAX_SIZE_DEFAULT = 256
const CHUNK_MAX_SIZE_DEFAULT = 200
const WINDOW_SIZE_DEFAULT = 3

var id_size = 256
var chunk_size = CHUNK_MAX_SIZE_DEFAULT # max size of snapshot in bytes
var buffer_size = ID_MAX_SIZE_DEFAULT * CHUNK_MAX_SIZE_DEFAULT
var buffer : PoolByteArray

var window_size = WINDOW_SIZE_DEFAULT
var preserve_snapshot_

# head is the next entry to consume
var head = 0

func _ready():
	buffer = PoolByteArray()

func init_buffer(id_size:int=ID_MAX_SIZE_DEFAULT, 
chunk_size:int=CHUNK_MAX_SIZE_DEFAULT):
	self.id_size = id_size
	self.chunk_size = chunk_size
	self.buffer_size = id_size * chunk_size

func store(chunk : PoolByteArray, index : int):
	pass
